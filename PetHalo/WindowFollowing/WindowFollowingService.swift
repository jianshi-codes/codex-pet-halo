import AppKit
import CoreGraphics
import Foundation

enum PetAttachmentUpdateMode: Equatable, Sendable {
    case snap
    case follow
}

enum HaloWindowFollowingEvent: Equatable, Sendable {
    case stateChanged(WindowFollowingState)
    case petDiscoveryStateChanged(PetTargetDiscoveryState)
    case targetSourceChanged(HaloFollowingTargetSource)
    case petPlacementStatusChanged(PetPlacementStatus)
    case petRingOrientationChanged(PetRingOrientation)
    case setCalibrationEnabled(Bool)
    case placeReferencePoint(CGPoint)
    case activatePetAttachment(PetAttachmentLayout)
    case placePetAttachment(PetAttachmentLayout, PetAttachmentUpdateMode)
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
    func resetPetVisualCenter()
    func samplePetAttachmentLayout() -> PetAttachmentLayout?
    func beginPresentationTransition()
    func finishPresentationTransition(panelSize: CGSize)
}

@MainActor
final class WindowFollowingService: HaloWindowFollowing {
    private enum CalibrationTarget: Equatable {
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
    private(set) var petPlacementStatus: PetPlacementStatus = .unavailable
    private var followingEnabled = false
    private var petFollowingSuppressed = false
    private var windowAnchor: HaloWindowAnchor?
    private var petVisualCenterOffset: PetVisualCenterOffset = .zero
    private var petSnapshot: PetTargetSnapshot?
    private var lastPetLayout: PetAttachmentLayout?
    private var windowFrame: CGRect?
    private var preCalibrationReferencePoint: CGPoint?
    private var preCalibrationPetFollowingSuppressed: Bool?
    private var calibrationTarget: CalibrationTarget?
    private var petRingOrientation: PetRingOrientation = .fixedDefault
    private var pendingPetRingOrientation: PetRingOrientation?
    private var petProcessIdentifier: Int32?
    private var petGeneration = 0
    private var windowGeneration = 0
    private var systemEventTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var petMovementRetryTask: Task<Void, Never>?
    private var petOrientationTask: Task<Void, Never>?
    private let petOrientationDebounce: Duration
    private let petMovementRetry: Duration
    private var started = false
    private var stopping = false

    init(
        permissionProvider: any AccessibilityPermissionProviding = SystemAccessibilityPermissionProvider(),
        applicationLocator: any CodexApplicationLocating = WorkspaceCodexApplicationLocator(),
        petAccessor: any PetTargetAccessing = AccessibilityPetTargetAccessor(),
        windowAccessor: any CodexWindowAccessing = AccessibilityCodexWindowAccessor(),
        systemEvents: any WindowFollowingSystemEventSourcing = WorkspaceWindowFollowingEventSource(),
        preferences: any WindowFollowingPreferenceStoring = UserDefaultsWindowFollowingPreferences(),
        petOrientationDebounce: Duration = .milliseconds(180),
        petMovementRetry: Duration = .milliseconds(16)
    ) {
        self.permissionProvider = permissionProvider
        self.applicationLocator = applicationLocator
        self.petAccessor = petAccessor
        self.windowAccessor = windowAccessor
        self.systemEvents = systemEvents
        self.preferences = preferences
        self.petOrientationDebounce = petOrientationDebounce
        self.petMovementRetry = petMovementRetry
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
        petVisualCenterOffset = saved.petVisualCenterOffset
        preferences.removeLegacyPetAnchor()
        transitionPlacementStatus(.unavailable)
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
        petMovementRetryTask?.cancel()
        petMovementRetryTask = nil
        petOrientationTask?.cancel()
        petOrientationTask = nil
        pendingPetRingOrientation = nil
        suspendCalibrationIfNeeded()
        petSnapshot = nil
        petProcessIdentifier = nil
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
        guard acceptsCommands, state != .calibrating else { return }
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
        guard acceptsCommands, followingEnabled, state != .calibrating else { return }
        petFollowingSuppressed = true
        petGeneration += 1
        petSnapshot = nil
        petProcessIdentifier = nil
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
        guard acceptsCommands,
              followingEnabled,
              state != .calibrating,
              targetSource == .pet,
              petSnapshot != nil
        else {
            return
        }
        preCalibrationReferencePoint = currentReferencePoint
        calibrationTarget = .pet
        transition(to: .calibrating)
        eventContinuation.yield(.setCalibrationEnabled(true))
    }

    func beginWindowCalibration(currentReferencePoint: CGPoint) {
        guard acceptsCommands, followingEnabled, state != .calibrating else { return }
        guard permissionProvider.state() == .granted else {
            transition(to: .permissionRequired)
            return
        }
        preCalibrationPetFollowingSuppressed = petFollowingSuppressed
        petFollowingSuppressed = true
        if windowFrame == nil {
            resolveWindowFallback()
        }
        guard windowFrame != nil else {
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
        switch calibrationTarget {
        case .pet:
            guard let snapshot = petAccessor.currentSnapshot() ?? petSnapshot,
                  let offset = PetAttachmentLayoutPolicy.visualCenterOffset(
                      panelReferencePoint: currentReferencePoint,
                      petFrame: snapshot.frame,
                      panelSize: PetAttachmentLayoutPolicy.petAttachmentSize
                  )
            else {
                suspendCalibrationIfNeeded()
                transition(to: .suspended(.invalidPlacement))
                return
            }
            petSnapshot = snapshot
            petVisualCenterOffset = offset
            preferences.setPetVisualCenterOffset(offset)
            schedulePetRingOrientation(for: snapshot)
        case .window:
            guard let frame = windowAccessor.currentFrame() ?? windowFrame,
                  let newAnchor = HaloAnchorGeometry.calibrate(
                      referencePoint: currentReferencePoint,
                      windowFrame: frame
                  )
            else {
                suspendCalibrationIfNeeded()
                transition(to: .suspended(.invalidPlacement))
                return
            }
            windowAnchor = newAnchor
            windowFrame = frame
            preferences.setWindowAnchor(newAnchor)
            petFollowingSuppressed = preCalibrationPetFollowingSuppressed ?? false
        }
        self.calibrationTarget = nil
        preCalibrationReferencePoint = nil
        preCalibrationPetFollowingSuppressed = nil
        eventContinuation.yield(.setCalibrationEnabled(false))
        if targetSource == .pet {
            applyPetPlacement(mode: .snap, force: true)
        } else {
            transition(to: .searching)
            resolvePreferredTarget()
        }
    }

    func cancelCalibration() {
        guard acceptsCommands, state == .calibrating else { return }
        let target = calibrationTarget
        suspendCalibrationIfNeeded()
        if target == .pet, petSnapshot != nil {
            applyPetPlacement(mode: .snap, force: true)
        } else {
            resolvePreferredTarget()
        }
    }

    func resetPetVisualCenter() {
        guard acceptsCommands,
              followingEnabled,
              targetSource == .pet,
              petSnapshot != nil
        else {
            return
        }
        if state == .calibrating, calibrationTarget == .pet {
            calibrationTarget = nil
            preCalibrationReferencePoint = nil
            eventContinuation.yield(.setCalibrationEnabled(false))
        }
        petVisualCenterOffset = .zero
        preferences.setPetVisualCenterOffset(.zero)
        if let petSnapshot {
            schedulePetRingOrientation(for: petSnapshot)
        }
        applyPetPlacement(mode: .snap, force: true)
    }

    func samplePetAttachmentLayout() -> PetAttachmentLayout? {
        guard acceptsCommands,
              followingEnabled,
              targetSource == .pet,
              !petFollowingSuppressed,
              !isPetVisualCenterCalibrationActive,
              let sample = petAccessor.currentTrackedFrame(),
              sample.generation == petGeneration,
              let currentSnapshot = petSnapshot,
              let layout = PetAttachmentLayoutPolicy.centeredLayout(
                  petFrame: sample.frame,
                  panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
                  visualCenterOffset: petVisualCenterOffset
              )
        else {
            return nil
        }
        petSnapshot = PetTargetSnapshot(
            generation: currentSnapshot.generation,
            frame: sample.frame,
            activityGeometryHint: currentSnapshot.activityGeometryHint,
            activityVerticalDelta: currentSnapshot.activityVerticalDelta
        )
        lastPetLayout = layout
        return layout
    }

    func beginPresentationTransition() {}

    func finishPresentationTransition(panelSize _: CGSize) {
        guard acceptsCommands else { return }
        if targetSource == .pet {
            applyPetPlacement()
        }
    }

    private var acceptsCommands: Bool {
        started && !stopping
    }

    private var isPetVisualCenterCalibrationActive: Bool {
        state == .calibrating && calibrationTarget == .pet
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
            petProcessIdentifier = nil
            petAccessor.stop()
            transitionPetDiscovery(to: .suspended)
            resolveWindowFallback()
            return
        }
        suspendCalibrationIfNeeded()
        transition(to: .searching)
        transitionPetDiscovery(to: .searching)
        let previousPetProcessIdentifier = petProcessIdentifier
        petGeneration += 1
        let currentGeneration = petGeneration
        petSnapshot = nil
        petProcessIdentifier = nil
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
            petProcessIdentifier = processIdentifier
            petSnapshot = snapshot
            schedulePetRingOrientation(for: snapshot)
            transitionPetDiscovery(to: .found)
            windowGeneration += 1
            windowFrame = nil
            windowAccessor.stop()
            applyPetPlacement(mode: previousPetProcessIdentifier == nil
                || previousPetProcessIdentifier == processIdentifier
                ? .follow
                : .snap)
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
        reason: WindowFollowingUnavailableReason? = nil
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
                applyWindowAnchor(finalState: .following)
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
                schedulePetMovementRetry(generation: generation)
                return
            }
            petSnapshot = snapshot
            schedulePetRingOrientation(for: snapshot)
            if !isPetVisualCenterCalibrationActive {
                applyPetPlacement(mode: .follow)
            }
        case .activityGeometryChanged:
            guard let snapshot = petAccessor.currentSnapshot(),
                  snapshot.generation == petGeneration
            else {
                return
            }
            schedulePetRingOrientation(for: snapshot)
        case .selectionChanged:
            guard petDiscoveryState == .found, petSnapshot != nil else {
                resolvePreferredTarget()
                return
            }
            if let snapshot = petAccessor.currentSnapshot(),
               snapshot.generation == petGeneration
            {
                let frameChanged = snapshot.frame != petSnapshot?.frame
                petSnapshot = snapshot
                schedulePetRingOrientation(for: snapshot)
                if frameChanged, !isPetVisualCenterCalibrationActive {
                    applyPetPlacement(mode: .snap)
                }
            } else {
                resolvePreferredTarget()
            }
        case .targetInvalidated:
            resolvePreferredTarget()
        }
    }

    private func schedulePetMovementRetry(generation: Int) {
        guard petMovementRetryTask == nil else { return }
        petMovementRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.petMovementRetry)
            guard !Task.isCancelled else { return }
            self.petMovementRetryTask = nil
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
                self.schedulePetRingOrientation(for: snapshot)
                if !self.isPetVisualCenterCalibrationActive {
                    self.applyPetPlacement(mode: .follow)
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
                    schedulePetRingOrientation(for: snapshot)
                    if !isPetVisualCenterCalibrationActive {
                        applyPetPlacement(mode: .snap)
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
        } else if targetSource == .pet, petDiscoveryState == .found {
            guard case let .selected(currentProcessIdentifier) = applicationLocator.locate(),
                  currentProcessIdentifier == petProcessIdentifier
            else {
                resolvePreferredTarget()
                return
            }
            guard let snapshot = petAccessor.currentSnapshot(),
                  snapshot.generation == petGeneration
            else {
                resolvePreferredTarget()
                return
            }
            let frameChanged = snapshot.frame != petSnapshot?.frame
            petSnapshot = snapshot
            schedulePetRingOrientation(for: snapshot)
            if frameChanged, !isPetVisualCenterCalibrationActive {
                applyPetPlacement(mode: .snap)
            }
        } else {
            resolvePreferredTarget()
        }
    }

    private func applyPetPlacement(
        mode: PetAttachmentUpdateMode = .follow,
        force: Bool = false
    ) {
        guard let petSnapshot else {
            transitionTarget(to: .freeFloating)
            transition(to: .suspended(.invalidPlacement))
            return
        }
        guard let layout = PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petSnapshot.frame,
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
            visualCenterOffset: petVisualCenterOffset
        ) else {
            transitionTarget(to: .freeFloating)
            transition(to: .suspended(.invalidPlacement))
            return
        }
        if targetSource != .pet {
            targetSource = .pet
            lastPetLayout = layout
            eventContinuation.yield(.activatePetAttachment(layout))
        } else if force || lastPetLayout != layout {
            lastPetLayout = layout
            eventContinuation.yield(.placePetAttachment(layout, mode))
        }
        transitionPlacementStatus(.centered)
        transition(to: .following)
    }

    private func schedulePetRingOrientation(for snapshot: PetTargetSnapshot) {
        let desired: PetRingOrientation
        switch snapshot.activityGeometryHint {
        case .none:
            desired = .fixedDefault
        case .above, .below:
            if let activityVerticalDelta = snapshot.activityVerticalDelta {
                let visualVerticalDelta = activityVerticalDelta
                    - petVisualCenterOffset.vertical
                guard abs(visualVerticalDelta) > 1 else { return }
                desired = visualVerticalDelta > 0 ? .openingTop : .openingBottom
            } else {
                desired = snapshot.activityGeometryHint == .above
                    ? .openingTop
                    : .openingBottom
            }
        case .ambiguous:
            return
        }
        guard desired != petRingOrientation || pendingPetRingOrientation != nil else { return }
        pendingPetRingOrientation = desired
        petOrientationTask?.cancel()
        let delay = petOrientationDebounce
        petOrientationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled,
                  let self,
                  self.acceptsCommands,
                  self.targetSource == .pet,
                  self.pendingPetRingOrientation == desired
            else {
                return
            }
            self.pendingPetRingOrientation = nil
            self.petOrientationTask = nil
            guard self.petRingOrientation != desired else { return }
            self.petRingOrientation = desired
            self.eventContinuation.yield(.petRingOrientationChanged(desired))
        }
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
        petMovementRetryTask?.cancel()
        petMovementRetryTask = nil
        petOrientationTask?.cancel()
        petOrientationTask = nil
        pendingPetRingOrientation = nil
        petSnapshot = nil
        petProcessIdentifier = nil
        windowFrame = nil
        petAccessor.stop()
        windowAccessor.stop()
    }

    private func suspendCalibrationIfNeeded() {
        guard state == .calibrating else { return }
        let target = calibrationTarget
        eventContinuation.yield(.setCalibrationEnabled(false))
        if target == .window, let previous = preCalibrationReferencePoint {
            eventContinuation.yield(.placeReferencePoint(previous))
        }
        if let previousSuppression = preCalibrationPetFollowingSuppressed {
            petFollowingSuppressed = previousSuppression
        }
        preCalibrationReferencePoint = nil
        preCalibrationPetFollowingSuppressed = nil
        calibrationTarget = nil
        transition(to: .searching)
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
        if newSource != .pet {
            lastPetLayout = nil
            transitionPlacementStatus(.unavailable)
        }
    }

    private func transitionPlacementStatus(_ newStatus: PetPlacementStatus) {
        guard petPlacementStatus != newStatus else { return }
        petPlacementStatus = newStatus
        eventContinuation.yield(.petPlacementStatusChanged(newStatus))
    }
}
