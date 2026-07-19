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
    @Published private(set) var bridgeStatusText = "Bridge: Starting"

    private let logger = Logger(subsystem: "io.github.jianshicodes.PetHalo", category: "lifecycle")
    private let usageService: any CodexUsageServing
    private let terminateApplication: @MainActor () -> Void
    private var bridgeStateTask: Task<Void, Never>?
    private var bridgeStartTask: Task<Void, Never>?
    private var shutdownTask: Task<Void, Never>?
    private var shutdownComplete = false

    init(
        usageService: (any CodexUsageServing)? = nil,
        terminateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.terminate(nil)
        }
    ) {
        self.usageService = usageService ?? CodexUsageService(
            applicationVersion: AppVersion.current().marketingVersion
        )
        self.terminateApplication = terminateApplication
    }

    func start() {
        guard state == .initialized else { return }
        state = .running
        logger.info("Application lifecycle started")
        bridgeStateTask = Task { [weak self, usageService] in
            let stream = await usageService.states()
            for await bridgeState in stream {
                guard let self else { return }
                self.updateBridgeStatus(bridgeState.connection)
            }
        }
        bridgeStartTask = Task { [usageService] in
            await usageService.start()
        }
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
        bridgeStateTask?.cancel()
        bridgeStateTask = nil
        bridgeStartTask?.cancel()
        bridgeStartTask = nil
        logger.info("Application lifecycle stopped")
    }

    func waitForShutdown() async {
        await shutdownTask?.value
    }

    private func beginShutdown(completion: @escaping @MainActor () -> Void) {
        guard shutdownTask == nil else { return }
        bridgeStartTask?.cancel()
        bridgeStartTask = nil
        shutdownTask = Task { [weak self, usageService] in
            await usageService.stop()
            guard let self else { return }
            self.bridgeStateTask?.cancel()
            self.bridgeStateTask = nil
            self.shutdownComplete = true
            self.bridgeStatusText = "Bridge: Unavailable"
            completion()
        }
    }

    private func updateBridgeStatus(_ connection: BridgeConnectionState) {
        guard state == .running else { return }
        switch connection {
        case .connected:
            bridgeStatusText = "Bridge: Connected"
        case .starting, .reconnecting:
            bridgeStatusText = "Bridge: Starting"
        case .stopped, .unavailable:
            bridgeStatusText = "Bridge: Unavailable"
        }
    }
}
