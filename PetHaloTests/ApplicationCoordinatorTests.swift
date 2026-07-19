import XCTest
import PetHaloCore
@testable import PetHalo

@MainActor
private final class FakeHaloPanelController: HaloPanelControlling {
    private(set) var isVisible = false
    private(set) var mode: HaloPresentationMode = .compact
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var stopCount = 0
    private(set) var models: [HaloPresentationModel] = []
    private var stopped = false

    func show() {
        guard !stopped, !isVisible else { return }
        isVisible = true
        showCount += 1
    }

    func hide() {
        guard !stopped, isVisible else { return }
        isVisible = false
        hideCount += 1
    }

    func setMode(_ mode: HaloPresentationMode) {
        guard !stopped else { return }
        self.mode = mode
    }

    func update(model: HaloPresentationModel) {
        guard !stopped else { return }
        models.append(model)
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        isVisible = false
        stopCount += 1
    }
}

private actor FakeUsageService: CodexUsageServing {
    private let stream: AsyncStream<CodexUsageState>
    private let continuation: AsyncStream<CodexUsageState>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0
    private(set) var statesCount = 0
    private(set) var panelWasStoppedWhenServiceStopped = false
    private let panelStopped: @MainActor @Sendable () -> Bool

    init(
        initialState: CodexUsageState = .stopped,
        panelStopped: @escaping @MainActor @Sendable () -> Bool = { true }
    ) {
        let pair = AsyncStream.makeStream(
            of: CodexUsageState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stream = pair.stream
        continuation = pair.continuation
        self.panelStopped = panelStopped
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
        panelWasStoppedWhenServiceStopped = await panelStopped()
        continuation.yield(.stopped)
    }

    func refresh() async {
        refreshCount += 1
    }

    func states() async -> AsyncStream<CodexUsageState> {
        statesCount += 1
        return stream
    }

    func emit(_ state: CodexUsageState) {
        continuation.yield(state)
    }
}

final class ApplicationCoordinatorTests: XCTestCase {
    @MainActor
    func testConnectedBridgePublishesSafeMenuStatus() async {
        let service = FakeUsageService()
        let panel = FakeHaloPanelController()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel,
            terminateApplication: {}
        )

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
        let panel = FakeHaloPanelController()
        let service = FakeUsageService(panelStopped: { panel.stopCount == 1 })
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel
        ) {
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
        XCTAssertEqual(panel.showCount, 1)
        XCTAssertEqual(panel.stopCount, 1)
        let stoppedInOrder = await service.panelWasStoppedWhenServiceStopped
        XCTAssertTrue(stoppedInOrder)

        coordinator.didTerminate()
        coordinator.didTerminate()
        XCTAssertEqual(coordinator.state, .stopped)
    }

    @MainActor
    func testTerminationBeforeStartIsIgnored() async {
        var terminationCount = 0
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: FakeHaloPanelController()
        ) {
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
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: FakeHaloPanelController()
        )
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
        let panel = FakeHaloPanelController()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel
        ) {
            terminationCount += 1
        }
        coordinator.start()
        coordinator.requestTermination()
        await coordinator.waitForShutdown()

        XCTAssertEqual(terminationCount, 1)
        XCTAssertEqual(coordinator.bridgeStatusText, "Bridge: Unavailable")
        XCTAssertEqual(panel.stopCount, 1)
    }

    @MainActor
    func testCoordinatorIsSingleStateConsumerAndMapsStateToPanel() async {
        let service = FakeUsageService()
        let panel = FakeHaloPanelController()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel,
            terminateApplication: {}
        )
        coordinator.start()
        for _ in 0 ..< 100 where coordinator.bridgeStatusText != "Bridge: Connected" {
            await Task.yield()
        }

        let weekly = QuotaWindow(
            source: .primary,
            usedPercent: 30,
            durationMinutes: 10_080,
            resetsAt: nil
        )
        await service.emit(
            CodexUsageState(
                connection: .connected,
                compatibility: .supported(version: "test"),
                snapshot: UsageSnapshot(
                    rateLimitBuckets: [],
                    accountUsage: nil,
                    collectedAt: Date()
                ),
                capabilities: UsageCapabilities(
                    generalWeekly: .available(weekly),
                    generalFiveHour: .unavailable(.matchingWindowMissing),
                    accountUsage: .unavailable(.unsupported)
                ),
                componentFreshness: UsageComponentFreshness(
                    rateLimits: .current,
                    accountUsage: .unavailable
                ),
                lastSuccessfulRefresh: Date(),
                failureReason: nil
            )
        )
        for _ in 0 ..< 100 where coordinator.haloPresentationModel.weekly.value == nil {
            await Task.yield()
        }

        XCTAssertEqual(coordinator.haloPresentationModel.weekly.value?.remainingText, "70%")
        XCTAssertEqual(panel.models.last, coordinator.haloPresentationModel)
        let statesCount = await service.statesCount
        XCTAssertEqual(statesCount, 1)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testHaloCommandsAndRefreshAreIdempotent() async {
        let service = FakeUsageService()
        let panel = FakeHaloPanelController()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel,
            terminateApplication: {}
        )
        coordinator.start()

        coordinator.setHaloMode(.expanded)
        coordinator.setHaloMode(.expanded)
        XCTAssertEqual(coordinator.haloMode, .expanded)
        coordinator.hideHalo()
        coordinator.hideHalo()
        XCTAssertFalse(coordinator.haloIsVisible)
        coordinator.showHalo()
        coordinator.showHalo()
        XCTAssertTrue(coordinator.haloIsVisible)
        coordinator.refreshUsage()
        coordinator.refreshUsage()
        await coordinator.waitForRefresh()

        XCTAssertEqual(panel.showCount, 2)
        XCTAssertEqual(panel.hideCount, 1)
        let refreshCount = await service.refreshCount
        XCTAssertEqual(refreshCount, 1)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }
}
