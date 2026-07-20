import CoreGraphics
import Foundation

enum HaloWindowFollowingEvent: Equatable, Sendable {
    case stateChanged(WindowFollowingState)
    case petDiscoveryStateChanged(PetTargetDiscoveryState)
    case targetSourceChanged(HaloFollowingTargetSource)
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
    func useWindowFallback()
    func disable()
    func beginPetCalibration(currentReferencePoint: CGPoint)
    func beginWindowCalibration(currentReferencePoint: CGPoint)
    func finishCalibration(currentReferencePoint: CGPoint)
    func cancelCalibration()
    func resetPetPosition()
}

@MainActor
final class WindowFollowingService: HaloWindowFollowing {
    private enum CalibrationTarget {
        case pet
        case window
    }

    private let permissionProvider: any AccessibilityPermissionProviding
    private let applicationLocator: any CodexApplicationLocating
    private let petAccessor: any PetTargetAccessing
    private let windowAccessor: any CodexWindowAccessing
    private let systemEvents: any WindowFollowingSystemEventSourcing
    private let preferences: any WindowFollowingPreferenceStoring
    private let eventStream: AsyncStream<HaloWindowFollowingEvent>
    private let eventContinuation: AsyncStream<HaloWindowFollowingEvent>.Continuation

    private(set) var state: WindowFollowingState = .disabled
    private(set) var petDiscoveryState: PetTargetDiscoveryState = .disabled
    private(set) var targetSource: HaloFollowingTargetSource = .freeFloating
    private var followingEnabled = false
    private var petFollowingSuppressed = false
    private var windowAnchor: HaloWindowAnchor?
    private var petAnchor: PetRelativeAnchor?
    private var petSnapshot: PetTargetSnapshot?
    private var windowFrame: CGRect?
    private var calibrationTarget: CalibrationTarget?
    private var preCalibrationReferencePoint: CGPoint?
    private var preCalibrationPetFollowingSuppressed: Bool?
    private var petGeneration = 0
    private var windowGeneration = 0
    private var systemEventTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var petStabilityTask: Task<Void, Never>?
    private var started = false
    private var stopping = false

    init(
        permissionProvider: any AccessibilityPermissionProviding = SystemAccessibilityPermissionProvider(),
        applicationLocator: any CodexApplicationLocating = WorkspaceCodexApplicationLocator(),
        petAccessor: any PetTargetAccessing = AccessibilityPetTargetAccessor(),
        windowAccessor: any CodexWindowAccessing = AccessibilityCodexWindowAccessor(),
        systemEvents: any WindowFollowingSystemEventSourcing = WorkspaceWindowFollowingEventSource(),
        preferences: any WindowFollowingPreferenceStoring = UserDefaultsWindowFollowingPreferences()
    ) {
        self.permissionProvider = permissionProvider
        self.applicationLocator = applicationLocator
        self.petAccessor = petAccessor
        self.windowAccessor = windowAccessor
        self.systemEvents = systemEvents
        self.preferences = preferences
        let pair = AsyncStream.makeStream(
            of: HaloWindowFollowingEvent.self,
            bufferingPolicy: .bufferingNewest(24)
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
        windowAnchor = saved.windowAnchor
        petAnchor = saved.petAnchor
        systemEvents.start()
        let stream = systemEvents.events()
        systemEventTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                self.handleSystemEvent(event)
            }
        }
        recoveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                self.recoverStateIfNeeded()
            }
        }
        guard followingEnabled else {
            transition(to: .disabled)
            transitionPetDiscovery(to: .disabled)
            transitionTarget(to: .freeFloating)
            return
        }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            transitionPetDiscovery(to: .suspended)
            transitionTarget(to: .freeFloating)
            return
        }
        resolvePreferredTarget()
    }

    func stop() async {
        guard started, !stopping else { return }
        stopping = true
        petGeneration += 1
        windowGeneration += 1
        petStabilityTask?.cancel()
        petStabilityTask = nil
        suspendCalibrationIfNeeded()
        petSnapshot = nil
        windowFrame = nil
        petAccessor.stop()
        windowAccessor.stop()
        systemEvents.stop()
        systemEventTask?.cancel()
        systemEventTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        started = false
        stopping = false
    }

    func enable() {
        guard acceptsCommands else { return }
        petFollowingSuppressed = false
        if !followingEnabled {
            followingEnabled = true
            preferences.setFollowingEnabled(true)
        }
        guard permissionProvider.request() == .granted else {
            suspendCalibrationIfNeeded()
            stopAccessors()
            transition(to: .permissionRequired)
            transitionPetDiscovery(to: .suspended)
            transitionTarget(to: .freeFloating)
            return
        }
        resolvePreferredTarget()
    }

    func useWindowFallback() {
        guard acceptsCommands, followingEnabled else { return }
        petFollowingSuppressed = true
        petGeneration += 1
        petSnapshot = nil
        petAccessor.stop()
        transitionPetDiscovery(to: .suspended)
        resolveWindowFallback()
    }

    func disable() {
        guard acceptsCommands, followingEnabled else { return }
        followingEnabled = false
        preferences.setFollowingEnabled(false)
        petFollowingSuppressed = false
        suspendCalibrationIfNeeded()
        stopAccessors()
        transitionPetDiscovery(to: .disabled)
        transitionTarget(to: .freeFloating)
        transition(to: .disabled)
    }

    func beginPetCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            return
        }
        let previousSuppression = petFollowingSuppressed
        if petSnapshot == nil {
            petFollowingSuppressed = false
            resolvePreferredTarget()
        }
        guard petSnapshot != nil, state != .calibrating else {
            petFollowingSuppressed = previousSuppression
            return
        }
        preCalibrationPetFollowingSuppressed = previousSuppression
        preCalibrationReferencePoint = currentReferencePoint
        calibrationTarget = .pet
        transition(to: .calibrating)
        eventContinuation.yield(.setCalibrationEnabled(true))
    }

    func beginWindowCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            return
        }
        preCalibrationPetFollowingSuppressed = petFollowingSuppressed
        petFollowingSuppressed = true
        if windowFrame == nil {
            resolveWindowFallback()
        }
        guard windowFrame != nil, state != .calibrating else {
            petFollowingSuppressed = preCalibrationPetFollowingSuppressed ?? false
            preCalibrationPetFollowingSuppressed = nil
            return
        }
        preCalibrationReferencePoint = currentReferencePoint
        calibrationTarget = .window
        transition(to: .calibrating)
        eventContinuation.yield(.setCalibrationEnabled(true))
    }

    func finishCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, state == .calibrating, let calibrationTarget else { return }
        let completed: Bool
        switch calibrationTarget {
        case .pet:
            guard let snapshot = petAccessor.currentSnapshot() ?? petSnapshot,
                  let newAnchor = PetAnchorGeometry.calibrate(
                      referencePoint: currentReferencePoint,
                      petFrame: snapshot.frame
                  )
            else {
                completed = false
                break
            }
            petAnchor = newAnchor
            petSnapshot = snapshot
            preferences.setPetAnchor(newAnchor)
            petFollowingSuppressed = false
            completed = true
        case .window:
            guard let frame = windowAccessor.currentFrame() ?? windowFrame,
                  let newAnchor = HaloAnchorGeometry.calibrate(
                      referencePoint: currentReferencePoint,
                      windowFrame: frame
                  )
            else {
                completed = false
                break
            }
            windowAnchor = newAnchor
            windowFrame = frame
            preferences.setWindowAnchor(newAnchor)
            petFollowingSuppressed = preCalibrationPetFollowingSuppressed ?? false
            completed = true
        }
        guard completed else {
            suspendCalibrationIfNeeded()
            transition(to: .suspended(.invalidPlacement))
            return
        }
        self.calibrationTarget = nil
        preCalibrationReferencePoint = nil
        preCalibrationPetFollowingSuppressed = nil
        eventContinuation.yield(.setCalibrationEnabled(false))
        transition(to: .searching)
        resolvePreferredTarget()
    }

    func cancelCalibration() {
        guard acceptsCommands, state == .calibrating else { return }
        resolvePreferredTarget()
    }

    func resetPetPosition() {
        guard acceptsCommands else { return }
        if calibrationTarget == .pet {
            suspendCalibrationIfNeeded()
        }
        petAnchor = nil
        preferences.setPetAnchor(nil)
        if followingEnabled {
            resolvePreferredTarget()
        }
    }

    private var acceptsCommands: Bool {
        started && !stopping
    }

    private func resolvePreferredTarget() {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            suspendCalibrationIfNeeded()
            stopAccessors()
            transition(to: .permissionRequired)
            transitionPetDiscovery(to: .suspended)
            transitionTarget(to: .freeFloating)
            return
        }
        if petFollowingSuppressed {
            petGeneration += 1
            petSnapshot = nil
            petAccessor.stop()
            transitionPetDiscovery(to: .suspended)
            resolveWindowFallback()
            return
        }
        suspendCalibrationIfNeeded()
        transition(to: .searching)
        transitionPetDiscovery(to: .searching)
        petGeneration += 1
        let currentGeneration = petGeneration
        petSnapshot = nil
        petAccessor.stop()

        let processIdentifier: Int32
        switch applicationLocator.locate() {
        case .unavailable:
            transitionPetDiscovery(to: .unavailable)
            resolveWindowFallback(reason: .codexUnavailable)
            return
        case .ambiguous:
            transitionPetDiscovery(to: .ambiguous)
            resolveWindowFallback(reason: .processAmbiguous)
            return
        case let .selected(selectedProcessIdentifier):
            processIdentifier = selectedProcessIdentifier
        }

        switch petAccessor.resolve(
            processIdentifier: processIdentifier,
            generation: currentGeneration,
            onEvent: { [weak self] event, eventGeneration in
                self?.handlePetEvent(event, generation: eventGeneration)
            }
        ) {
        case let .selected(snapshot):
            petSnapshot = snapshot
            transitionPetDiscovery(to: .found)
            if petAnchor != nil {
                windowGeneration += 1
                windowFrame = nil
                windowAccessor.stop()
                applyPetAnchor()
            } else {
                resolveWindowFallback(processIdentifier: processIdentifier, petNeedsCalibration: true)
            }
        case .unavailable:
            transitionPetDiscovery(to: .unavailable)
            resolveWindowFallback(processIdentifier: processIdentifier)
        case .ambiguous:
            transitionPetDiscovery(to: .ambiguous)
            resolveWindowFallback(processIdentifier: processIdentifier)
        case .observerFailed:
            transitionPetDiscovery(to: .suspended)
            resolveWindowFallback(processIdentifier: processIdentifier, reason: .observerFailed)
        }
    }

    private func resolveWindowFallback(
        processIdentifier: Int32? = nil,
        reason: WindowFollowingUnavailableReason? = nil,
        petNeedsCalibration: Bool = false
    ) {
        guard acceptsCommands, followingEnabled else { return }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            transitionTarget(to: .freeFloating)
            return
        }
        let selectedProcessIdentifier: Int32
        if let processIdentifier {
            selectedProcessIdentifier = processIdentifier
        } else {
            switch applicationLocator.locate() {
            case .unavailable:
                windowFrame = nil
                windowAccessor.stop()
                transitionTarget(to: .freeFloating)
                transition(to: .unavailable(reason ?? .codexUnavailable))
                return
            case .ambiguous:
                windowFrame = nil
                windowAccessor.stop()
                transitionTarget(to: .freeFloating)
                transition(to: .unavailable(reason ?? .processAmbiguous))
                return
            case let .selected(value):
                selectedProcessIdentifier = value
            }
        }

        windowGeneration += 1
        let currentGeneration = windowGeneration
        windowFrame = nil
        windowAccessor.stop()
        switch windowAccessor.resolve(
            processIdentifier: selectedProcessIdentifier,
            generation: currentGeneration,
            onEvent: { [weak self] event, eventGeneration in
                self?.handleWindowEvent(event, generation: eventGeneration)
            }
        ) {
        case let .selected(frame):
            windowFrame = frame
            if windowAnchor != nil {
                applyWindowAnchor(finalState: petNeedsCalibration ? .calibrationRequired : .following)
            } else {
                transitionTarget(to: .freeFloating)
                transition(to: .calibrationRequired)
            }
        case .unavailable:
            transitionTarget(to: .freeFloating)
            transition(to: .suspended(reason ?? .windowUnavailable))
        case .ambiguous:
            transitionTarget(to: .freeFloating)
            transition(to: .unavailable(reason ?? .windowAmbiguous))
        case .observerFailed:
            transitionTarget(to: .freeFloating)
            transition(to: .suspended(reason ?? .observerFailed))
        }
    }

    private func handlePetEvent(_ event: PetTargetObservationEvent, generation: Int) {
        guard acceptsCommands,
              followingEnabled,
              !petFollowingSuppressed,
              generation == petGeneration
        else {
            return
        }
        switch event {
        case .geometryChanged:
            guard let snapshot = petAccessor.currentSnapshot(),
                  snapshot.generation == petGeneration
            else {
                schedulePetStabilityCheck(generation: generation)
                return
            }
            petSnapshot = snapshot
            if state != .calibrating, petAnchor != nil {
                applyPetAnchor()
            }
        case .selectionChanged, .targetInvalidated:
            if state == .calibrating,
               calibrationTarget == .pet,
               let snapshot = petAccessor.currentSnapshot(),
               snapshot.generation == petGeneration
            {
                petSnapshot = snapshot
                return
            }
            resolvePreferredTarget()
        }
    }

    private func schedulePetStabilityCheck(generation: Int) {
        guard petStabilityTask == nil else { return }
        petStabilityTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, let self else { return }
            self.petStabilityTask = nil
            guard self.acceptsCommands,
                  generation == self.petGeneration,
                  !self.petFollowingSuppressed
            else {
                return
            }
            if let snapshot = self.petAccessor.currentSnapshot(),
               snapshot.generation == self.petGeneration
            {
                self.petSnapshot = snapshot
                if self.state != .calibrating, self.petAnchor != nil {
                    self.applyPetAnchor()
                }
            } else {
                self.resolvePreferredTarget()
            }
        }
    }

    private func handleWindowEvent(_ event: CodexWindowObservationEvent, generation: Int) {
        guard acceptsCommands,
              followingEnabled,
              generation == windowGeneration
        else {
            return
        }
        switch event {
        case .geometryChanged:
            guard let frame = windowAccessor.currentFrame() else {
                windowFrame = nil
                transitionTarget(to: .freeFloating)
                transition(to: .suspended(.windowUnavailable))
                return
            }
            windowFrame = frame
            if state != .calibrating, targetSource == .codexWindowFallback {
                applyWindowAnchor(finalState: state == .calibrationRequired
                    ? .calibrationRequired
                    : .following)
            }
        case .selectionChanged, .targetInvalidated:
            resolvePreferredTarget()
        }
    }

    private func handleSystemEvent(_ event: WindowFollowingSystemEvent) {
        guard acceptsCommands, followingEnabled else { return }
        switch event {
        case .codexEnvironmentChanged:
            resolvePreferredTarget()
        case .displayConfigurationChanged:
            switch targetSource {
            case .pet:
                if let snapshot = petAccessor.currentSnapshot() {
                    petSnapshot = snapshot
                    if state != .calibrating {
                        applyPetAnchor()
                    }
                } else {
                    resolvePreferredTarget()
                }
            case .codexWindowFallback:
                if let frame = windowAccessor.currentFrame() {
                    windowFrame = frame
                    if state != .calibrating {
                        applyWindowAnchor(finalState: state)
                    }
                } else {
                    resolvePreferredTarget()
                }
            case .freeFloating:
                resolvePreferredTarget()
            }
        }
    }

    func recoverStateIfNeeded() {
        guard acceptsCommands, followingEnabled, state != .calibrating else { return }
        if permissionProvider.state() != .granted {
            suspendCalibrationIfNeeded()
            stopAccessors()
            transition(to: .permissionRequired)
            transitionPetDiscovery(to: .suspended)
            transitionTarget(to: .freeFloating)
        } else if petFollowingSuppressed {
            if targetSource == .freeFloating {
                resolveWindowFallback()
            }
        } else if targetSource != .pet || petDiscoveryState != .found {
            resolvePreferredTarget()
        }
    }

    private func applyPetAnchor() {
        guard let petAnchor, let petSnapshot else {
            transition(to: .calibrationRequired)
            return
        }
        guard let referencePoint = PetAnchorGeometry.referencePoint(
            anchor: petAnchor,
            petFrame: petSnapshot.frame
        ) else {
            transition(to: .suspended(.invalidPlacement))
            return
        }
        eventContinuation.yield(.placeReferencePoint(referencePoint))
        transitionTarget(to: .pet)
        transition(to: .following)
    }

    private func applyWindowAnchor(finalState: WindowFollowingState) {
        guard let windowAnchor, let windowFrame else {
            transitionTarget(to: .freeFloating)
            transition(to: .calibrationRequired)
            return
        }
        guard let referencePoint = HaloAnchorGeometry.referencePoint(
            anchor: windowAnchor,
            windowFrame: windowFrame
        ) else {
            transitionTarget(to: .freeFloating)
            transition(to: .suspended(.invalidPlacement))
            return
        }
        eventContinuation.yield(.placeReferencePoint(referencePoint))
        transitionTarget(to: .codexWindowFallback)
        transition(to: finalState)
    }

    private func stopAccessors() {
        petGeneration += 1
        windowGeneration += 1
        petStabilityTask?.cancel()
        petStabilityTask = nil
        petSnapshot = nil
        windowFrame = nil
        petAccessor.stop()
        windowAccessor.stop()
    }

    private func suspendCalibrationIfNeeded() {
        guard state == .calibrating else { return }
        eventContinuation.yield(.setCalibrationEnabled(false))
        if let previous = preCalibrationReferencePoint {
            eventContinuation.yield(.placeReferencePoint(previous))
        }
        if let previousSuppression = preCalibrationPetFollowingSuppressed {
            petFollowingSuppressed = previousSuppression
        }
        preCalibrationReferencePoint = nil
        preCalibrationPetFollowingSuppressed = nil
        calibrationTarget = nil
    }

    private func transition(to newState: WindowFollowingState) {
        guard state != newState else { return }
        state = newState
        eventContinuation.yield(.stateChanged(newState))
    }

    private func transitionPetDiscovery(to newState: PetTargetDiscoveryState) {
        guard petDiscoveryState != newState else { return }
        petDiscoveryState = newState
        eventContinuation.yield(.petDiscoveryStateChanged(newState))
    }

    private func transitionTarget(to newSource: HaloFollowingTargetSource) {
        guard targetSource != newSource else { return }
        targetSource = newSource
        eventContinuation.yield(.targetSourceChanged(newSource))
    }
}
