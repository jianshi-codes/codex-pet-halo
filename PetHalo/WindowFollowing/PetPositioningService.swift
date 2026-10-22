import AppKit

/// Fixed positioning by default; periodic single images require an explicit toggle.
@MainActor
final class PetPositioningService: HaloWindowFollowing {
    private let stream: AsyncStream<HaloWindowFollowingEvent>
    private let continuation: AsyncStream<HaloWindowFollowingEvent>.Continuation
    private let capture: @MainActor (Int32) async -> CGRect?
    private let applicationLocator: any CodexApplicationLocating
    private let systemEvents: any WindowFollowingSystemEventSourcing
    private let followingDelay: @MainActor () async throws -> Void
    private var task: Task<Void, Never>?
    private var followingTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var generation = 0
    private var started = false
    private var continuousFollowingEnabled = false
    private var processIdentifier: Int32?
    private var pendingRequest = false
    private var layout: PetAttachmentLayout?

    init(
        applicationLocator: any CodexApplicationLocating = WorkspaceCodexApplicationLocator(),
        systemEvents: any WindowFollowingSystemEventSourcing = WorkspaceWindowFollowingEventSource(),
        followingDelay: @escaping @MainActor () async throws -> Void = {
            try await Task.sleep(for: .seconds(1))
        },
        capture: (@MainActor (Int32) async -> CGRect?)? = nil
    ) {
        let pair = AsyncStream.makeStream(of: HaloWindowFollowingEvent.self)
        stream = pair.stream
        continuation = pair.continuation
        self.applicationLocator = applicationLocator
        self.systemEvents = systemEvents
        self.followingDelay = followingDelay
        var requestedScreenCaptureAccess = false
        self.capture = capture ?? { pid in
            // Release lifecycle smoke does not exercise TCC or Pet positioning.
            guard ProcessInfo.processInfo.environment["PET_HALO_RELEASE_SMOKE_DIAGNOSTIC_PATH"] == nil
            else { return nil }
            if !CGPreflightScreenCaptureAccess() {
                guard !requestedScreenCaptureAccess else { return nil }
                requestedScreenCaptureAccess = true
                _ = CGRequestScreenCaptureAccess()
            }
            return await OneShotPetCapture.capturePet(processIdentifier: pid)
        }
    }

    func events() -> AsyncStream<HaloWindowFollowingEvent> { stream }

    func start() {
        guard !started else { return }
        started = true
        let events = systemEvents.events()
        systemEvents.start()
        eventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled, let self else { return }
                if event == .codexEnvironmentChanged { self.updateApplication() }
            }
        }
        updateApplication()
    }

    private func updateApplication() {
        guard started else { return }
        let selection = applicationLocator.locate()
        let pid: Int32?
        if case let .selected(selectedPID) = selection { pid = selectedPID } else { pid = nil }
        guard pid != processIdentifier else { return }
        cancelRequests()
        processIdentifier = pid
        layout = nil
        continuation.yield(.targetSourceChanged(.freeFloating))
        if pid != nil {
            pendingRequest = true
            enable()
        } else {
            continuation.yield(.petDiscoveryStateChanged(.unavailable))
        }
    }

    func enable() {
        guard started, let pid = processIdentifier, task == nil else { return }
        pendingRequest = false
        followingTask?.cancel()
        followingTask = nil
        generation += 1
        let request = generation
        continuation.yield(.petDiscoveryStateChanged(.searching))
        task = Task { [weak self, capture] in
            let frame = await capture(pid)
            guard let self else { return }
            self.task = nil
            if !Task.isCancelled, self.started, self.generation == request {
                // Recheck the actual process before accepting an asynchronous image.
                self.updateApplication()
                if self.generation == request {
                    if let frame,
                       let layout = PetAttachmentLayoutPolicy.centeredLayout(
                        petFrame: frame,
                        panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
                        visualCenterOffset: .zero
                       ) {
                        self.layout = layout
                        self.continuation.yield(.petDiscoveryStateChanged(.found))
                        self.continuation.yield(.petPlacementStatusChanged(.centered))
                        self.continuation.yield(.activatePetAttachment(layout))
                    } else {
                        self.continuation.yield(.petDiscoveryStateChanged(.unavailable))
                        // Failed relocation preserves the last successful position.
                    }
                }
            }
            if self.pendingRequest { self.enable() }
            self.scheduleFollowing()
        }
    }

    func setContinuousFollowingEnabled(_ enabled: Bool) {
        guard started, continuousFollowingEnabled != enabled else { return }
        continuousFollowingEnabled = enabled
        if enabled {
            enable()
        } else {
            cancelRequests()
            continuation.yield(.petDiscoveryStateChanged(layout == nil ? .unavailable : .found))
        }
    }

    private func scheduleFollowing() {
        guard started, continuousFollowingEnabled, processIdentifier != nil,
              task == nil, followingTask == nil else { return }
        followingTask = Task { [weak self, followingDelay] in
            do { try await followingDelay() } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.followingTask = nil
            self.updateApplication()
            self.enable()
        }
    }

    private func cancelRequests() {
        generation += 1
        pendingRequest = false
        task?.cancel()
        // Keep the in-flight slot until capture returns, preventing overlap.
        followingTask?.cancel()
        followingTask = nil
    }

    func stop() async {
        started = false
        cancelRequests()
        systemEvents.stop()
        eventTask?.cancel()
        eventTask = nil
        layout = nil
        processIdentifier = nil
        continuation.finish()
    }

    func samplePetAttachmentLayout() -> PetAttachmentLayout? { nil }
    func beginPresentationTransition() {}
    func finishPresentationTransition(panelSize: CGSize) {
        if let layout { continuation.yield(.placePetAttachment(layout, .snap)) }
    }
    // Legacy protocol commands retained for injected milestone test services.
    func useWindowFallback() {}
    func disable() { setContinuousFollowingEnabled(false) }
    func beginPetCalibration(currentReferencePoint: CGPoint) {}
    func beginWindowCalibration(currentReferencePoint: CGPoint) {}
    func finishCalibration(currentReferencePoint: CGPoint) {}
    func cancelCalibration() {}
    func resetPetVisualCenter() {}
}
