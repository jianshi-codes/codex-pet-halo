import CoreGraphics
import Foundation

enum HaloWindowFollowingEvent: Equatable, Sendable {
    case stateChanged(WindowFollowingState)
    case setCalibrationEnabled(Bool)
    case placeReferencePoint(CGPoint)
    case resetToDefaultPosition
}

@MainActor
protocol HaloWindowFollowing: AnyObject {
    func events() -> AsyncStream<HaloWindowFollowingEvent>
    func start()
    func stop() async
    func enable()
    func disable()
    func beginCalibration(currentReferencePoint: CGPoint)
    func finishCalibration(currentReferencePoint: CGPoint)
    func cancelCalibration()
    func resetPosition()
}

@MainActor
final class WindowFollowingService: HaloWindowFollowing {
    private let permissionProvider: any AccessibilityPermissionProviding
    private let applicationLocator: any CodexApplicationLocating
    private let windowAccessor: any CodexWindowAccessing
    private let systemEvents: any WindowFollowingSystemEventSourcing
    private let preferences: any WindowFollowingPreferenceStoring
    private let eventStream: AsyncStream<HaloWindowFollowingEvent>
    private let eventContinuation: AsyncStream<HaloWindowFollowingEvent>.Continuation

    private(set) var state: WindowFollowingState = .disabled
    private var followingEnabled = false
    private var anchor: HaloWindowAnchor?
    private var targetFrame: CGRect?
    private var preCalibrationReferencePoint: CGPoint?
    private var generation = 0
    private var systemEventTask: Task<Void, Never>?
    private var permissionRecoveryTask: Task<Void, Never>?
    private var started = false
    private var stopping = false

    init(
        permissionProvider: any AccessibilityPermissionProviding = SystemAccessibilityPermissionProvider(),
        applicationLocator: any CodexApplicationLocating = WorkspaceCodexApplicationLocator(),
        windowAccessor: any CodexWindowAccessing = AccessibilityCodexWindowAccessor(),
        systemEvents: any WindowFollowingSystemEventSourcing = WorkspaceWindowFollowingEventSource(),
        preferences: any WindowFollowingPreferenceStoring = UserDefaultsWindowFollowingPreferences()
    ) {
        self.permissionProvider = permissionProvider
        self.applicationLocator = applicationLocator
        self.windowAccessor = windowAccessor
        self.systemEvents = systemEvents
        self.preferences = preferences
        let pair = AsyncStream.makeStream(
            of: HaloWindowFollowingEvent.self,
            bufferingPolicy: .bufferingNewest(16)
        )
        eventStream = pair.stream
        eventContinuation = pair.continuation
    }

    func events() -> AsyncStream<HaloWindowFollowingEvent> {
        eventStream
    }

    func start() {
        guard !started else { return }
        started = true
        let saved = preferences.load()
        followingEnabled = saved.followingEnabled
        anchor = saved.anchor
        systemEvents.start()
        let stream = systemEvents.events()
        systemEventTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                self.handleSystemEvent(event)
            }
        }
        permissionRecoveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                self.recoverPermissionStateIfNeeded()
            }
        }
        guard followingEnabled else {
            transition(to: .disabled)
            return
        }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            return
        }
        resolveTarget()
    }

    func stop() async {
        guard started, !stopping else { return }
        stopping = true
        generation += 1
        if state == .calibrating {
            eventContinuation.yield(.setCalibrationEnabled(false))
        }
        preCalibrationReferencePoint = nil
        targetFrame = nil
        windowAccessor.stop()
        systemEvents.stop()
        systemEventTask?.cancel()
        systemEventTask = nil
        permissionRecoveryTask?.cancel()
        permissionRecoveryTask = nil
        started = false
        stopping = false
    }

    func enable() {
        guard acceptsCommands else { return }
        followingEnabled = true
        preferences.setFollowingEnabled(true)
        guard permissionProvider.request() == .granted else {
            suspendCalibrationIfNeeded()
            windowAccessor.stop()
            targetFrame = nil
            transition(to: .permissionRequired)
            return
        }
        resolveTarget()
    }

    func disable() {
        guard acceptsCommands, followingEnabled else { return }
        followingEnabled = false
        preferences.setFollowingEnabled(false)
        suspendCalibrationIfNeeded()
        generation += 1
        targetFrame = nil
        windowAccessor.stop()
        transition(to: .disabled)
    }

    func beginCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            return
        }
        if targetFrame == nil {
            resolveTarget()
        }
        guard targetFrame != nil else { return }
        guard state != .calibrating else { return }
        preCalibrationReferencePoint = currentReferencePoint
        transition(to: .calibrating)
        eventContinuation.yield(.setCalibrationEnabled(true))
    }

    func finishCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, state == .calibrating else { return }
        guard permissionProvider.state() == .granted,
              let frame = windowAccessor.currentFrame() ?? targetFrame,
              let newAnchor = HaloAnchorGeometry.calibrate(
                  referencePoint: currentReferencePoint,
                  windowFrame: frame
              )
        else {
            suspendCalibrationIfNeeded()
            transition(to: .suspended(.windowUnavailable))
            return
        }
        anchor = newAnchor
        targetFrame = frame
        preferences.setAnchor(newAnchor)
        preCalibrationReferencePoint = nil
        eventContinuation.yield(.setCalibrationEnabled(false))
        applyAnchor()
    }

    func cancelCalibration() {
        guard acceptsCommands, state == .calibrating else { return }
        eventContinuation.yield(.setCalibrationEnabled(false))
        if let previous = preCalibrationReferencePoint {
            eventContinuation.yield(.placeReferencePoint(previous))
        }
        preCalibrationReferencePoint = nil
        if anchor != nil, targetFrame != nil {
            applyAnchor()
        } else {
            transition(to: .calibrationRequired)
        }
    }

    func resetPosition() {
        guard acceptsCommands else { return }
        suspendCalibrationIfNeeded()
        anchor = nil
        preferences.setAnchor(nil)
        if followingEnabled {
            followingEnabled = false
            preferences.setFollowingEnabled(false)
        }
        generation += 1
        targetFrame = nil
        windowAccessor.stop()
        eventContinuation.yield(.resetToDefaultPosition)
        transition(to: .disabled)
    }

    private var acceptsCommands: Bool {
        started && !stopping
    }

    private func resolveTarget() {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            suspendCalibrationIfNeeded()
            targetFrame = nil
            windowAccessor.stop()
            transition(to: .permissionRequired)
            return
        }
        suspendCalibrationIfNeeded()
        transition(to: .searching)
        generation += 1
        let currentGeneration = generation
        windowAccessor.stop()

        let processIdentifier: Int32
        switch applicationLocator.locate() {
        case .unavailable:
            targetFrame = nil
            transition(to: .unavailable(.codexUnavailable))
            return
        case .ambiguous:
            targetFrame = nil
            transition(to: .unavailable(.processAmbiguous))
            return
        case let .selected(selectedProcessIdentifier):
            processIdentifier = selectedProcessIdentifier
        }

        switch windowAccessor.resolve(
            processIdentifier: processIdentifier,
            generation: currentGeneration,
            onEvent: { [weak self] event, eventGeneration in
                self?.handleWindowEvent(event, generation: eventGeneration)
            }
        ) {
        case let .selected(frame):
            targetFrame = frame
            if anchor == nil {
                transition(to: .calibrationRequired)
            } else {
                applyAnchor()
            }
        case .unavailable:
            targetFrame = nil
            transition(to: .suspended(.windowUnavailable))
        case .ambiguous:
            targetFrame = nil
            transition(to: .unavailable(.windowAmbiguous))
        case .observerFailed:
            targetFrame = nil
            transition(to: .suspended(.observerFailed))
        }
    }

    private func handleWindowEvent(_ event: CodexWindowObservationEvent, generation: Int) {
        guard acceptsCommands,
              followingEnabled,
              generation == self.generation
        else {
            return
        }
        switch event {
        case .geometryChanged:
            guard let frame = windowAccessor.currentFrame() else {
                targetFrame = nil
                transition(to: .suspended(.windowUnavailable))
                return
            }
            targetFrame = frame
            if state != .calibrating {
                applyAnchor()
            }
        case .selectionChanged, .targetInvalidated:
            resolveTarget()
        }
    }

    private func handleSystemEvent(_ event: WindowFollowingSystemEvent) {
        guard acceptsCommands, followingEnabled else { return }
        switch event {
        case .codexEnvironmentChanged:
            resolveTarget()
        case .displayConfigurationChanged:
            if let frame = windowAccessor.currentFrame() {
                targetFrame = frame
                if state != .calibrating {
                    applyAnchor()
                }
            } else {
                resolveTarget()
            }
        }
    }

    private func recoverPermissionStateIfNeeded() {
        guard acceptsCommands, followingEnabled else { return }
        if permissionProvider.state() != .granted {
            suspendCalibrationIfNeeded()
            generation += 1
            targetFrame = nil
            windowAccessor.stop()
            transition(to: .permissionRequired)
        } else if state == .permissionRequired {
            resolveTarget()
        }
    }

    private func applyAnchor() {
        guard let anchor, let targetFrame else {
            transition(to: .calibrationRequired)
            return
        }
        guard let referencePoint = HaloAnchorGeometry.referencePoint(
            anchor: anchor,
            windowFrame: targetFrame
        ) else {
            transition(to: .suspended(.invalidPlacement))
            return
        }
        eventContinuation.yield(.placeReferencePoint(referencePoint))
        transition(to: .following)
    }

    private func suspendCalibrationIfNeeded() {
        guard state == .calibrating else { return }
        eventContinuation.yield(.setCalibrationEnabled(false))
        if let previous = preCalibrationReferencePoint {
            eventContinuation.yield(.placeReferencePoint(previous))
        }
        preCalibrationReferencePoint = nil
    }

    private func transition(to newState: WindowFollowingState) {
        guard state != newState else { return }
        state = newState
        eventContinuation.yield(.stateChanged(newState))
    }
}
