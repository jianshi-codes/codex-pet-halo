import AppKit
import Combine
import OSLog
import PetHaloCore

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

    private let logger = Logger(subsystem: "io.github.jianshicodes.PetHalo", category: "lifecycle")
    private let usageService: any CodexUsageServing
    private let presentationMapper: HaloPresentationMapper
    private let terminateApplication: @MainActor () -> Void
    private var haloPanelController: (any HaloPanelControlling)?
    private var bridgeStateTask: Task<Void, Never>?
    private var bridgeStartTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var shutdownTask: Task<Void, Never>?
    private var shutdownComplete = false

    init(
        usageService: (any CodexUsageServing)? = nil,
        haloPanelController: (any HaloPanelControlling)? = nil,
        presentationMapper: HaloPresentationMapper = HaloPresentationMapper(),
        terminateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.terminate(nil)
        }
    ) {
        self.usageService = usageService ?? CodexUsageService(
            applicationVersion: AppVersion.current().marketingVersion
        )
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
        updateUsageState(Self.startingUsageState)
        haloPanelController?.setMode(.compact)
        haloMode = .compact
        haloPanelController?.show()
        haloIsVisible = haloPanelController?.isVisible == true
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
        guard state == .running else { return }
        haloPanelController?.setMode(mode)
        haloMode = haloPanelController?.mode ?? mode
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
        haloPanelController?.stop()
        haloIsVisible = false
        refreshTask?.cancel()
        refreshTask = nil
        bridgeStartTask?.cancel()
        bridgeStartTask = nil
        shutdownTask = Task { [weak self, usageService] in
            await usageService.stop()
            guard let self else { return }
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
