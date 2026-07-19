import AppKit
import OSLog

@MainActor
final class ApplicationCoordinator {
    enum State: Equatable {
        case initialized
        case running
        case terminationRequested
        case stopped
    }

    private(set) var state: State = .initialized

    private let logger = Logger(subsystem: "io.github.jianshicodes.PetHalo", category: "lifecycle")
    private let terminateApplication: @MainActor () -> Void

    init(terminateApplication: @escaping @MainActor () -> Void = {
        NSApplication.shared.terminate(nil)
    }) {
        self.terminateApplication = terminateApplication
    }

    func start() {
        guard state == .initialized else { return }
        state = .running
        logger.info("Application lifecycle started")
    }

    func requestTermination() {
        guard state == .running else { return }
        state = .terminationRequested
        logger.info("Application termination requested")
        terminateApplication()
    }

    func didTerminate() {
        guard state != .stopped else { return }
        state = .stopped
        logger.info("Application lifecycle stopped")
    }
}
