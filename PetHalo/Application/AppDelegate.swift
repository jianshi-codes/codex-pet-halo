import AppKit
import PetHaloCore

#if DEBUG
private actor XCTestDisabledUsageService: CodexUsageServing {
    func start() async {}
    func stop() async {}
    func refresh() async {}

    func states() -> AsyncStream<CodexUsageState> {
        AsyncStream { continuation in
            continuation.yield(.stopped)
            continuation.finish()
        }
    }
}
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: ApplicationCoordinator

    override init() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            coordinator = ApplicationCoordinator(usageService: XCTestDisabledUsageService())
        } else {
            coordinator = ApplicationCoordinator()
        }
        #else
        coordinator = ApplicationCoordinator()
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.didTerminate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if coordinator.prepareForSystemTermination {
            coordinator.requestSystemTermination {
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
        return .terminateNow
    }
}
