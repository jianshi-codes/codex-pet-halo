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
    @Published private(set) var latestUsageState: CodexUsageState
    @Published private(set) var haloPresentationModel: HaloPresentationModel
    @Published private(set) var haloMode: HaloPresentationMode = .compact
    @Published private(set) var haloIsVisible = false
    @Published private(set) var windowFollowingState: WindowFollowingState = .disabled
    @Published private(set) var followingStatusText = WindowFollowingState.disabled.statusText
    @Published private(set) var petDiscoveryState: PetTargetDiscoveryState = .disabled
    @Published private(set) var petStatusText = PetTargetDiscoveryState.disabled.statusText
    @Published private(set) var targetSource: HaloFollowingTargetSource = .freeFloating
    @Published private(set) var targetStatusText = HaloFollowingTargetSource.freeFloating.statusText
    @Published private(set) var petPlacementStatus: PetPlacementStatus = .unavailable
    @Published private(set) var petPlacementStatusText = PetPlacementStatus.unavailable.statusText

    private let logger = Logger(subsystem: "io.github.jianshicodes.PetHalo", category: "lifecycle")
    private let usageService: any CodexUsageServing
    private let windowFollowingService: any HaloWindowFollowing
    private let presentationMapper: HaloPresentationMapper
    private let terminateApplication: @MainActor () -> Void
    private var haloPanelController: (any HaloPanelControlling)?
    private var bridgeStateTask: Task<Void, Never>?
    private var windowFollowingEventTask: Task<Void, Never>?
    private var bridgeStartTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var shutdownTask: Task<Void, Never>?
    private var shutdownComplete = false
    private var previousNonPetHaloMode: HaloPresentationMode?

    init(
        usageService: (any CodexUsageServing)? = nil,
        haloPanelController: (any HaloPanelControlling)? = nil,
        windowFollowingService: (any HaloWindowFollowing)? = nil,
        presentationMapper: HaloPresentationMapper = HaloPresentationMapper(),
        terminateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.terminate(nil)
        }
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
        self.terminateApplication = terminateApplication
        latestUsageState = .stopped
        haloPresentationModel = presentationMapper.map(.stopped)
        bridgeStatusText = "Bridge: Starting"
        self.haloPanelController = haloPanelController
            ?? HaloPanelController(model: haloPresentationModel)
    }

    func start() {
        guard state == .initialized else { return }
        state = .running
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
        haloPanelController?.setMode(.compact)
        haloMode = .compact
        haloPanelController?.show()
        haloIsVisible = haloPanelController?.isVisible == true
        windowFollowingService.start()
        bridgeStartTask = Task { [usageService] in
            await usageService.start()
        }
    }

    func showHalo() {
        guard state == .running else { return }
        haloPanelController?.show()
        haloIsVisible = haloPanelController?.isVisible == true
    }

    func hideHalo() {
        guard state == .running else { return }
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

    var canFinishCalibration: Bool {
        state == .running && windowFollowingState == .calibrating
    }

    var canDisableWindowFollowing: Bool {
        state == .running && windowFollowingState != .disabled
    }

    var canUseWindowFallback: Bool {
        state == .running
            && targetSource == .pet
            && windowFollowingState != .calibrating
    }

    func enablePetFollowing() {
        guard canEnablePetFollowing else { return }
        windowFollowingService.enable()
    }

    func useWindowFallback() {
        guard canUseWindowFallback else { return }
        windowFollowingService.useWindowFallback()
    }

    func disableWindowFollowing() {
        guard state == .running else { return }
        windowFollowingService.disable()
    }

    func beginPetFollowingCalibration() {
        guard state == .running, let haloPanelController else { return }
        windowFollowingService.beginPetCalibration(
            currentReferencePoint: haloPanelController.referencePoint
        )
    }

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
        state == .running && latestUsageState.connection == .connected
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
            self.bridgeStatusText = "Bridge: Unavailable"
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
            let previousSource = targetSource
            targetSource = newSource
            targetStatusText = newSource.statusText
            if newSource == .pet {
                if previousSource != .pet {
                    previousNonPetHaloMode = haloMode
                }
                if haloMode != .compact {
                    applyHaloMode(.compact)
                }
            } else if previousSource == .pet,
                      let mode = previousNonPetHaloMode
            {
                previousNonPetHaloMode = nil
                if haloMode != mode {
                    applyHaloMode(mode)
                }
            }
        case let .petPlacementStatusChanged(newStatus):
            petPlacementStatus = newStatus
            petPlacementStatusText = newStatus.statusText
        case let .setCalibrationEnabled(enabled):
            haloPanelController?.setCalibrationEnabled(enabled)
        case let .placeReferencePoint(referencePoint):
            haloPanelController?.setReferencePoint(referencePoint)
        case let .placePetAttachment(layout):
            haloPanelController?.setAttachmentLayout(layout)
        case .resetToDefaultPosition:
            haloPanelController?.resetToDefaultPosition()
        }
    }

    private func updateUsageState(_ usageState: CodexUsageState) {
        guard state == .running else { return }
        latestUsageState = usageState
        haloPresentationModel = presentationMapper.map(usageState)
        haloPanelController?.update(model: haloPresentationModel)
        switch usageState.connection {
        case .connected:
            bridgeStatusText = "Bridge: Connected"
        case .starting, .reconnecting:
            bridgeStatusText = "Bridge: Starting"
        case .stopped, .unavailable:
            bridgeStatusText = "Bridge: Unavailable"
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
