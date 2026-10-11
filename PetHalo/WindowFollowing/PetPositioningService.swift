import AppKit

/// Captures once per explicit request. No observers, polling, or tracking sampler.
@MainActor
final class PetPositioningService: HaloWindowFollowing {
    private let stream: AsyncStream<HaloWindowFollowingEvent>
    private let continuation: AsyncStream<HaloWindowFollowingEvent>.Continuation
    private let capture: @MainActor () async -> CGRect?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var started = false
    private var layout: PetAttachmentLayout?

    init(capture: (@MainActor () async -> CGRect?)? = nil) {
        let pair = AsyncStream.makeStream(of: HaloWindowFollowingEvent.self)
        stream = pair.stream
        continuation = pair.continuation
        self.capture = capture ?? {
            // Release lifecycle smoke does not exercise TCC or Pet positioning.
            guard ProcessInfo.processInfo.environment["PET_HALO_RELEASE_SMOKE_DIAGNOSTIC_PATH"] == nil
            else { return nil }
            guard case let .selected(pid) = WorkspaceCodexApplicationLocator().locate() else {
                return nil
            }
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
            return await OneShotPetCapture.capturePet(processIdentifier: pid)
        }
    }

    func events() -> AsyncStream<HaloWindowFollowingEvent> { stream }

    func start() {
        guard !started else { return }
        started = true
        enable()
    }

    func enable() {
        guard started, task == nil else { return }
        generation += 1
        let request = generation
        continuation.yield(.petDiscoveryStateChanged(.searching))
        task = Task { [weak self, capture] in
            let frame = await capture()
            guard let self, !Task.isCancelled, self.generation == request else { return }
            self.task = nil
            guard let frame,
                  let layout = PetAttachmentLayoutPolicy.centeredLayout(
                    petFrame: frame,
                    panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
                    visualCenterOffset: .zero
                  )
            else {
                self.continuation.yield(.petDiscoveryStateChanged(.unavailable))
                return // Preserve the last successful position on failed requests.
            }
            self.layout = layout
            self.continuation.yield(.petDiscoveryStateChanged(.found))
            self.continuation.yield(.petPlacementStatusChanged(.centered))
            self.continuation.yield(.activatePetAttachment(layout))
        }
    }

    func stop() async {
        started = false
        generation += 1
        task?.cancel()
        task = nil
        continuation.finish()
    }

    func samplePetAttachmentLayout() -> PetAttachmentLayout? { nil }
    func beginPresentationTransition() {}
    func finishPresentationTransition(panelSize: CGSize) {
        if let layout { continuation.yield(.placePetAttachment(layout, .snap)) }
    }
    // Legacy protocol commands retained for injected milestone test services.
    func useWindowFallback() {}
    func disable() {}
    func beginPetCalibration(currentReferencePoint: CGPoint) {}
    func beginWindowCalibration(currentReferencePoint: CGPoint) {}
    func finishCalibration(currentReferencePoint: CGPoint) {}
    func cancelCalibration() {}
    func resetPetVisualCenter() {}
}
