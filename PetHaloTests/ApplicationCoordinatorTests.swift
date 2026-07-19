import XCTest
import PetHaloCore
@testable import PetHalo

private actor FakeUsageService: CodexUsageServing {
    private let stream: AsyncStream<CodexUsageState>
    private let continuation: AsyncStream<CodexUsageState>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0

    init(initialState: CodexUsageState = .stopped) {
        let pair = AsyncStream.makeStream(
            of: CodexUsageState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stream = pair.stream
        continuation = pair.continuation
        continuation.yield(initialState)
    }

    func start() async {
        startCount += 1
        continuation.yield(
            CodexUsageState(
                connection: .connected,
                compatibility: .supported(version: "test"),
                snapshot: nil,
                capabilities: .unavailable,
                componentFreshness: .unavailable,
                lastSuccessfulRefresh: nil,
                failureReason: nil
            )
        )
    }

    func stop() async {
        stopCount += 1
        continuation.yield(.stopped)
    }

    func refresh() async {
        refreshCount += 1
    }

    func states() async -> AsyncStream<CodexUsageState> {
        stream
    }
}

final class ApplicationCoordinatorTests: XCTestCase {
    @MainActor
    func testConnectedBridgePublishesOnlyTechnicalMenuState() async {
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(usageService: service, terminateApplication: {})

        coordinator.start()
        for _ in 0 ..< 100 where coordinator.bridgeStatusText != "Bridge: Connected" {
            await Task.yield()
        }

        XCTAssertEqual(coordinator.bridgeStatusText, "Bridge: Connected")
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testLifecycleTransitionsStartAndTerminateBridgeOnce() async {
        var terminationCount = 0
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(usageService: service) {
            terminationCount += 1
        }

        XCTAssertEqual(coordinator.state, .initialized)

        coordinator.start()
        coordinator.start()
        XCTAssertEqual(coordinator.state, .running)

        coordinator.requestTermination()
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
        XCTAssertEqual(coordinator.state, .terminationRequested)
        XCTAssertEqual(terminationCount, 1)
        let startCount = await service.startCount
        let stopCount = await service.stopCount
        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(stopCount, 1)

        coordinator.didTerminate()
        coordinator.didTerminate()
        XCTAssertEqual(coordinator.state, .stopped)
    }

    @MainActor
    func testTerminationBeforeStartIsIgnored() async {
        var terminationCount = 0
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(usageService: service) {
            terminationCount += 1
        }

        coordinator.requestTermination()

        XCTAssertEqual(coordinator.state, .initialized)
        XCTAssertEqual(terminationCount, 0)
        let stopCount = await service.stopCount
        XCTAssertEqual(stopCount, 0)
    }

    @MainActor
    func testSystemTerminationWaitsForBridgeShutdownAndIsIdempotent() async {
        var replyCount = 0
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(usageService: service)
        coordinator.start()

        XCTAssertTrue(coordinator.prepareForSystemTermination)
        coordinator.requestSystemTermination {
            replyCount += 1
        }
        coordinator.requestSystemTermination {
            replyCount += 1
        }
        await coordinator.waitForShutdown()

        XCTAssertEqual(replyCount, 1)
        let stopCount = await service.stopCount
        XCTAssertEqual(stopCount, 1)
        XCTAssertFalse(coordinator.prepareForSystemTermination)
    }

    @MainActor
    func testUnavailableBridgeDoesNotBlockQuit() async {
        let unavailable = CodexUsageState(
            connection: .unavailable,
            compatibility: .unsupported(version: "future"),
            snapshot: nil,
            capabilities: .unavailable,
            componentFreshness: .unavailable,
            lastSuccessfulRefresh: nil,
            failureReason: .unsupportedProtocolVersion
        )
        let service = FakeUsageService(initialState: unavailable)
        var terminationCount = 0
        let coordinator = ApplicationCoordinator(usageService: service) {
            terminationCount += 1
        }
        coordinator.start()
        coordinator.requestTermination()
        await coordinator.waitForShutdown()

        XCTAssertEqual(terminationCount, 1)
        XCTAssertEqual(coordinator.bridgeStatusText, "Bridge: Unavailable")
    }
}
