import AppKit
import Combine
import OSLog
import PetHaloCore

#if DEBUG
@MainActor
private final class XCTestDisabledWindowFollowingService: HaloWindowFollowing {
    private let stream: AsyncStream<HaloWindowFollowingEvent>

    init() {
        stream = AsyncStream { continuation in
            continuation.yield(.stateChanged(.disabled))
        }
    }

    func events() -> AsyncStream<HaloWindowFollowingEvent> { stream }
    func start() {}
    func stop() async {}
    func enable() {}
    func useWindowFallback() {}
    func disable() {}
    func beginPetCalibration(currentReferencePoint: CGPoint) {}
    func beginWindowCalibration(currentReferencePoint: CGPoint) {}
    func finishCalibration(currentReferencePoint: CGPoint) {}
    func cancelCalibration() {}
    func resetPetVisualCenter() {}
    func samplePetAttachmentLayout() -> PetAttachmentLayout? { nil }
    func beginPresentationTransition() {}
    func finishPresentationTransition(panelSize: CGSize) {}
}
#endif

@MainActor
final class ApplicationCoordinator: ObservableObject {
    enum State: Equatable {
        case initialized
        case running
        case terminationRequested
        case stopped
    }

    private(set) var state: State = .initialized
    @Published private(set) var bridgeStatusText: String
    @Published private(set) var cliStatusText: String
    @Published private(set) var latestUsageState: CodexUsageState
    @Published private(set) var haloPresentationModel: HaloPresentationModel
    @Published private(set) var petRingPresentationModel: PetRingPresentationModel
    @Published private(set) var haloMode: HaloPresentationMode = .compact
    @Published private(set) var haloSurfaceMode: HaloSurfaceMode = .compactCard
    @Published private(set) var haloIsVisible = false
    @Published private(set) var windowFollowingState: WindowFollowingState = .disabled
    @Published private(set) var followingStatusText = WindowFollowingState.disabled.statusText
    @Published private(set) var petDiscoveryState: PetTargetDiscoveryState = .disabled
    @Published private(set) var petStatusText = PetTargetDiscoveryState.disabled.statusText
    @Published private(set) var targetSource: HaloFollowingTargetSource = .freeFloating
    @Published private(set) var targetStatusText = HaloFollowingTargetSource.freeFloating.statusText
    @Published private(set) var petPlacementStatus: PetPlacementStatus = .unavailable
    @Published private(set) var petPlacementStatusText = PetPlacementStatus.unavailable.statusText
    @Published private(set) var petRingOrientation: PetRingOrientation = .fixedDefault
    #if DEBUG
    @Published private(set) var petRingOrientationPreview =
        PetRingOrientationPreview.from(arguments: ProcessInfo.processInfo.arguments)
    #endif

    private let logger = Logger(subsystem: "io.github.jianshicodes.PetHalo", category: "lifecycle")
    private let usageService: any CodexUsageServing
    private let windowFollowingService: any HaloWindowFollowing
    private let presentationMapper: HaloPresentationMapper
    private let petRingPresentationMapper: PetRingPresentationMapper
    private let currentDate: @MainActor () -> Date
    private let terminateApplication: @MainActor () -> Void
    private var haloPanelController: (any HaloPanelControlling)?
    private var bridgeStateTask: Task<Void, Never>?
    private var windowFollowingEventTask: Task<Void, Never>?
    private var bridgeStartTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var shutdownTask: Task<Void, Never>?
    private var shutdownComplete = false
    private var previousNonPetHaloMode: HaloPresentationMode?
    private var previousNonPetReferencePoint: CGPoint?
    private var haloVisibilityRequested = true
    private var codexFallbackExplicitlyVisible = false
    private var productionPetRingOrientation: PetRingOrientation = .fixedDefault

    init(
        usageService: (any CodexUsageServing)? = nil,
        haloPanelController: (any HaloPanelControlling)? = nil,
        windowFollowingService: (any HaloWindowFollowing)? = nil,
        presentationMapper: HaloPresentationMapper = HaloPresentationMapper(),
        petRingPresentationMapper: PetRingPresentationMapper = PetRingPresentationMapper(),
        terminateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.terminate(nil)
        },
        currentDate: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.usageService = usageService ?? CodexUsageService(
            applicationVersion: AppVersion.current().marketingVersion
        )
        if let windowFollowingService {
            self.windowFollowingService = windowFollowingService
        } else {
            #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if environment["XCTestConfigurationFilePath"] != nil
                || environment["XCTestBundlePath"] != nil
            {
                self.windowFollowingService = XCTestDisabledWindowFollowingService()
            } else {
                self.windowFollowingService = WindowFollowingService()
            }
            #else
            self.windowFollowingService = WindowFollowingService()
            #endif
        }
        self.presentationMapper = presentationMapper
        self.petRingPresentationMapper = petRingPresentationMapper
        self.currentDate = currentDate
        self.terminateApplication = terminateApplication
        latestUsageState = .stopped
        haloPresentationModel = presentationMapper.map(.stopped)
        petRingPresentationModel = petRingPresentationMapper.map(.stopped, date: currentDate())
        bridgeStatusText = "Usage: Connecting"
        cliStatusText = "CLI: Detecting"
        self.haloPanelController = haloPanelController
            ?? HaloPanelController(model: haloPresentationModel)
    }

    func start() {
        guard state == .initialized else { return }
        state = .running
        haloPanelController?.setPetAttachmentSampler { [weak self] in
            self?.windowFollowingService.samplePetAttachmentLayout()
        }
        logger.info("Application lifecycle started")
        bridgeStateTask = Task { [weak self, usageService] in
            let stream = await usageService.states()
            for await bridgeState in stream {
                guard let self else { return }
                self.updateUsageState(bridgeState)
            }
        }
        let followingEvents = windowFollowingService.events()
        windowFollowingEventTask = Task { [weak self] in
            for await event in followingEvents {
                guard let self else { return }
                self.handleWindowFollowingEvent(event)
            }
        }
        updateUsageState(Self.startingUsageState)
        haloPanelController?.setSurfaceMode(.compactCard)
        applyEffectivePetRingOrientation()
        haloMode = .compact
        haloSurfaceMode = .compactCard
        windowFollowingService.start()
        bridgeStartTask = Task { [usageService] in
            await usageService.start()
        }
    }

    func showHalo() {
        guard canShowHalo else { return }
        haloVisibilityRequested = true
        haloPanelController?.show()
        haloIsVisible = haloPanelController?.isVisible == true
    }

    func hideHalo() {
        guard state == .running else { return }
        haloVisibilityRequested = false
        haloPanelController?.hide()
        haloIsVisible = haloPanelController?.isVisible == true
    }

    func setHaloMode(_ mode: HaloPresentationMode) {
        guard canChangeHaloMode else { return }
        applyHaloMode(mode)
    }

    private func applyHaloMode(_ mode: HaloPresentationMode) {
        windowFollowingService.beginPresentationTransition()
        haloPanelController?.setMode(mode)
        haloMode = haloPanelController?.mode ?? mode
        haloSurfaceMode = haloPanelController?.surfaceMode ?? HaloSurfaceMode(cardMode: mode)
        windowFollowingService.finishPresentationTransition(
            panelSize: haloPanelController?.frame.size ?? HaloPanelController.size(for: mode)
        )
    }

    func refreshUsage() {
        guard canRefreshUsage, refreshTask == nil else { return }
        refreshTask = Task { [weak self, usageService] in
            await usageService.refresh()
            guard let self else { return }
            self.refreshTask = nil
        }
    }

    var acceptsUICommands: Bool {
        state == .running
    }

    var canShowHalo: Bool {
        state == .running
            && !haloIsVisible
            && (targetSource == .pet
                || (targetSource == .codexWindowFallback && codexFallbackExplicitlyVisible))
    }

    var canChangeHaloMode: Bool {
        state == .running
            && targetSource != .pet
            && windowFollowingState != .calibrating
    }

    var canEnablePetFollowing: Bool {
        state == .running && targetSource != .pet && windowFollowingState != .calibrating
    }

    var canCalibrateWindowFallback: Bool {
        state == .running
            && windowFollowingState != .disabled
            && windowFollowingState != .permissionRequired
            && windowFollowingState != .calibrating
    }

    var canFineTunePetRing: Bool {
        state == .running
            && targetSource == .pet
            && petDiscoveryState == .found
            && windowFollowingState != .calibrating
    }

    var canFinishCalibration: Bool {
        state == .running && windowFollowingState == .calibrating
    }

    var isAdjustingPetRingCenter: Bool {
        canFinishCalibration && targetSource == .pet
    }

    var canDisableWindowFollowing: Bool {
        state == .running && windowFollowingState != .disabled
    }

    var canUseWindowFallback: Bool {
        state == .running
            && targetSource != .freeFloating
            && !codexFallbackExplicitlyVisible
            && windowFollowingState != .calibrating
    }

    func enablePetFollowing() {
        guard canEnablePetFollowing else { return }
        codexFallbackExplicitlyVisible = false
        haloVisibilityRequested = true
        windowFollowingService.enable()
    }

    func useWindowFallback() {
        guard canUseWindowFallback else { return }
        codexFallbackExplicitlyVisible = true
        haloVisibilityRequested = true
        windowFollowingService.useWindowFallback()
        showHaloIfEligible()
    }

    func disableWindowFollowing() {
        guard state == .running else { return }
        windowFollowingService.disable()
    }

    func beginPetFollowingCalibration() {
        guard canFineTunePetRing, let haloPanelController else { return }
        windowFollowingService.beginPetCalibration(
            currentReferencePoint: haloPanelController.referencePoint
        )
    }

    func nudgePetRing(horizontal: CGFloat, vertical: CGFloat) {
        guard isAdjustingPetRingCenter, let haloPanelController else { return }
        let current = haloPanelController.referencePoint
        haloPanelController.setReferencePoint(
            CGPoint(
                x: current.x + horizontal,
                y: current.y + vertical
            )
        )
    }

    func resetPetVisualCenter() {
        guard state == .running, targetSource == .pet else { return }
        windowFollowingService.resetPetVisualCenter()
    }

    #if DEBUG
    func setPetRingOrientationPreview(_ preview: PetRingOrientationPreview) {
        guard state == .running else { return }
        petRingOrientationPreview = preview
        applyEffectivePetRingOrientation()
    }
    #endif

    func beginWindowFallbackCalibration() {
        guard canCalibrateWindowFallback, let haloPanelController else { return }
        windowFollowingService.beginWindowCalibration(
            currentReferencePoint: haloPanelController.referencePoint
        )
    }

    func finishWindowFollowingCalibration() {
        guard state == .running, let haloPanelController else { return }
        windowFollowingService.finishCalibration(
            currentReferencePoint: haloPanelController.referencePoint
        )
    }

    func cancelWindowFollowingCalibration() {
        guard state == .running else { return }
        windowFollowingService.cancelCalibration()
    }

    var canRefreshUsage: Bool {
        state == .running
            && (latestUsageState.connection == .connected
                || latestUsageState.failureReason == .runtimeIncompatible)
    }

    func requestTermination() {
        guard state == .running else { return }
        state = .terminationRequested
        logger.info("Application termination requested")
        beginShutdown(completion: terminateApplication)
    }

    var prepareForSystemTermination: Bool {
        state == .running && !shutdownComplete
    }

    func requestSystemTermination(reply: @escaping @MainActor () -> Void) {
        guard state == .running else { return }
        state = .terminationRequested
        logger.info("Application system termination requested")
        beginShutdown(completion: reply)
    }

    func didTerminate() {
        guard state != .stopped else { return }
        state = .stopped
        windowFollowingEventTask?.cancel()
        windowFollowingEventTask = nil
        Task { [windowFollowingService] in
            await windowFollowingService.stop()
        }
        haloPanelController?.stop()
        haloPanelController = nil
        haloIsVisible = false
        refreshTask?.cancel()
        refreshTask = nil
        bridgeStateTask?.cancel()
        bridgeStateTask = nil
        bridgeStartTask?.cancel()
        bridgeStartTask = nil
        logger.info("Application lifecycle stopped")
    }

    func waitForShutdown() async {
        await shutdownTask?.value
    }

    func waitForRefresh() async {
        await refreshTask?.value
    }

    private func beginShutdown(completion: @escaping @MainActor () -> Void) {
        guard shutdownTask == nil else { return }
        refreshTask?.cancel()
        refreshTask = nil
        bridgeStartTask?.cancel()
        bridgeStartTask = nil
        shutdownTask = Task { [weak self, usageService, windowFollowingService] in
            await windowFollowingService.stop()
            guard let self else { return }
            self.windowFollowingEventTask?.cancel()
            self.windowFollowingEventTask = nil
            self.haloPanelController?.stop()
            self.haloIsVisible = false
            await usageService.stop()
            self.bridgeStateTask?.cancel()
            self.bridgeStateTask = nil
            self.shutdownComplete = true
            self.latestUsageState = .stopped
            self.haloPresentationModel = self.presentationMapper.map(.stopped)
            self.petRingPresentationModel = self.petRingPresentationMapper.map(
                .stopped,
                date: self.currentDate()
            )
            self.bridgeStatusText = "Usage: Temporarily unavailable"
            self.cliStatusText = "CLI: Detecting"
            self.haloPanelController = nil
            completion()
        }
    }

    private func handleWindowFollowingEvent(_ event: HaloWindowFollowingEvent) {
        guard state == .running else { return }
        switch event {
        case let .stateChanged(newState):
            windowFollowingState = newState
            followingStatusText = newState.statusText
        case let .petDiscoveryStateChanged(newState):
            petDiscoveryState = newState
            petStatusText = newState.statusText
        case let .targetSourceChanged(newSource):
            applyTargetSource(newSource)
        case let .petPlacementStatusChanged(newStatus):
            petPlacementStatus = newStatus
            petPlacementStatusText = newStatus.statusText
        case let .petRingOrientationChanged(newOrientation):
            productionPetRingOrientation = newOrientation
            applyEffectivePetRingOrientation()
        case let .setCalibrationEnabled(enabled):
            haloPanelController?.setCalibrationEnabled(enabled)
        case let .placeReferencePoint(referencePoint):
            haloPanelController?.setReferencePoint(referencePoint)
        case let .activatePetAttachment(layout):
            applyTargetSource(.pet)
            haloPanelController?.setAttachmentLayout(layout)
            showHaloIfEligible()
        case let .placePetAttachment(layout, mode):
            switch mode {
            case .snap:
                haloPanelController?.setAttachmentLayout(layout)
            case .follow:
                haloPanelController?.followAttachmentLayout(layout)
            }
        case .resetToDefaultPosition:
            haloPanelController?.resetToDefaultPosition()
        }
    }

    private func applyEffectivePetRingOrientation() {
        #if DEBUG
        let effective = petRingOrientationPreview.orientation(
            auto: productionPetRingOrientation
        )
        #else
        let effective = productionPetRingOrientation
        #endif
        petRingOrientation = effective
        haloPanelController?.setPetRingOrientation(effective)
    }

    private func applyTargetSource(_ newSource: HaloFollowingTargetSource) {
        let previousSource = targetSource
        targetSource = newSource
        targetStatusText = newSource.statusText
        if newSource == .pet {
            codexFallbackExplicitlyVisible = false
            if previousSource != .pet {
                previousNonPetHaloMode = haloMode
                previousNonPetReferencePoint = haloPanelController?.referencePoint
            }
            haloPanelController?.setSurfaceMode(.petRing)
            haloSurfaceMode = .petRing
        } else if previousSource == .pet,
                  let mode = previousNonPetHaloMode
        {
            if haloPanelController?.attachmentLayout != nil,
               let referencePoint = previousNonPetReferencePoint
            {
                haloPanelController?.setReferencePoint(referencePoint)
            }
            previousNonPetHaloMode = nil
            previousNonPetReferencePoint = nil
            applyHaloMode(mode)
        }
        if newSource == .codexWindowFallback, codexFallbackExplicitlyVisible {
            showHaloIfEligible()
        } else if newSource != .pet {
            hideHaloForUnavailablePet()
        }
    }

    private func showHaloIfEligible() {
        guard haloVisibilityRequested,
              targetSource == .pet
                || (targetSource == .codexWindowFallback && codexFallbackExplicitlyVisible)
        else {
            return
        }
        haloPanelController?.show()
        haloIsVisible = haloPanelController?.isVisible == true
    }

    private func hideHaloForUnavailablePet() {
        haloPanelController?.hide()
        haloIsVisible = haloPanelController?.isVisible == true
    }

    private func updateUsageState(_ usageState: CodexUsageState) {
        guard state == .running else { return }
        latestUsageState = usageState
        haloPresentationModel = presentationMapper.map(usageState)
        petRingPresentationModel = petRingPresentationMapper.map(
            usageState,
            date: currentDate()
        )
        haloPanelController?.update(
            cardModel: haloPresentationModel,
            petRingModel: petRingPresentationModel
        )
        bridgeStatusText = Self.usageStatusText(for: usageState)
        cliStatusText = Self.cliStatusText(for: usageState.compatibility)
    }

    static func usageStatusText(for usageState: CodexUsageState) -> String {
        if usageState.failureReason == .unsupportedProtocolVersion {
            return "Usage: Unsupported Codex CLI version"
        }
        if usageState.failureReason == .runtimeIncompatible {
            return "Usage: CLI runtime incompatible"
        }
        if usageState.failureReason == .executableMissing {
            return "Usage: Codex CLI not found"
        }
        if usageState.failureReason == .authenticationUnavailable {
            return "Usage: Sign in to Codex"
        }
        if usageState.failureReason == .rateLimitsUnavailable {
            return "Usage: Rate limits temporarily unavailable"
        }
        if usageState.failureReason == .accountUsageUnavailable
            || usageState.failureReason == .accountUsageUnsupported
        {
            return "Usage: Today temporarily unavailable"
        }

        switch usageState.connection {
        case .connected:
            return "Usage: Connected"
        case .starting, .reconnecting:
            return "Usage: Connecting"
        case .stopped, .unavailable:
            return "Usage: Temporarily unavailable"
        }
    }

    static func cliStatusText(for compatibility: ProtocolCompatibilityState) -> String {
        switch compatibility {
        case .unknown:
            return "CLI: Detecting"
        case let .reviewed(version):
            return "CLI: \(version)"
        case let .provisional(version):
            return "CLI: \(version) · provisional"
        case let .blocked(version):
            if let version {
                return "CLI: \(version) · blocked"
            }
            return "CLI: blocked"
        case let .runtimeIncompatible(version):
            return "CLI: \(version) · incompatible"
        }
    }

    private static let startingUsageState = CodexUsageState(
        connection: .starting,
        compatibility: .unknown,
        snapshot: nil,
        capabilities: .unavailable,
        componentFreshness: .unavailable,
        lastSuccessfulRefresh: nil,
        failureReason: nil
    )
}
