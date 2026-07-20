import XCTest
import PetHaloCore
@testable import PetHalo

@MainActor
private final class FakeHaloPanelController: HaloPanelControlling {
    private(set) var isVisible = false
    private(set) var mode: HaloPresentationMode = .compact
    private(set) var frame = CGRect(x: 100, y: 100, width: 176, height: 176)
    private(set) var isCalibrationEnabled = false
    private(set) var attachmentLayout: PetAttachmentLayout?
    private(set) var ignoresMouseEvents = true
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var stopCount = 0
    private(set) var models: [HaloPresentationModel] = []
    private var stopped = false

    var referencePoint: CGPoint {
        HaloPlacementGeometry.referencePoint(for: frame)
    }

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
        frame.size = HaloPanelController.size(for: mode)
        ignoresMouseEvents = !isCalibrationEnabled && mode == .compact
    }

    func setReferencePoint(_ referencePoint: CGPoint) {
        guard !stopped else { return }
        attachmentLayout = nil
        frame = HaloPlacementGeometry.frame(referencePoint: referencePoint, size: frame.size)
    }

    func setAttachmentLayout(_ layout: PetAttachmentLayout) {
        guard !stopped else { return }
        attachmentLayout = layout
        frame = layout.panelFrame
    }

    func setCalibrationEnabled(_ enabled: Bool) {
        guard !stopped else { return }
        isCalibrationEnabled = enabled
        ignoresMouseEvents = enabled ? false : mode == .compact
    }

    func resetToDefaultPosition() {
        guard !stopped else { return }
        frame.origin = CGPoint(x: 0, y: 0)
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

@MainActor
private final class FakeWindowFollowingService: HaloWindowFollowing {
    private let stream: AsyncStream<HaloWindowFollowingEvent>
    private let continuation: AsyncStream<HaloWindowFollowingEvent>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var enableCount = 0
    private(set) var useWindowFallbackCount = 0
    private(set) var disableCount = 0
    private(set) var beginPetCount = 0
    private(set) var beginWindowCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0
    private(set) var resetCount = 0
    private(set) var presentationTransitionCount = 0
    var eventsOnCancel: [HaloWindowFollowingEvent] = []

    init() {
        let pair = AsyncStream.makeStream(
            of: HaloWindowFollowingEvent.self,
            bufferingPolicy: .bufferingNewest(16)
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func events() -> AsyncStream<HaloWindowFollowingEvent> { stream }
    func start() {
        startCount += 1
        continuation.yield(.stateChanged(.disabled))
    }
    func stop() async { stopCount += 1 }
    func enable() { enableCount += 1 }
    func useWindowFallback() { useWindowFallbackCount += 1 }
    func disable() { disableCount += 1 }
    func beginPetCalibration(currentReferencePoint: CGPoint) { beginPetCount += 1 }
    func beginWindowCalibration(currentReferencePoint: CGPoint) { beginWindowCount += 1 }
    func finishCalibration(currentReferencePoint: CGPoint) { finishCount += 1 }
    func cancelCalibration() {
        cancelCount += 1
        for event in eventsOnCancel {
            continuation.yield(event)
        }
    }
    func resetPetPosition() { resetCount += 1 }
    func beginPresentationTransition() { presentationTransitionCount += 1 }
    func finishPresentationTransition(panelSize: CGSize) { presentationTransitionCount += 1 }

    func emit(_ event: HaloWindowFollowingEvent) {
        continuation.yield(event)
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
        XCTAssertFalse(coordinator.canRefreshUsage)
        coordinator.refreshUsage()
        let disconnectedRefreshCount = await service.refreshCount
        XCTAssertEqual(disconnectedRefreshCount, 0)
        coordinator.start()

        for _ in 0 ..< 100 where !coordinator.canRefreshUsage {
            await Task.yield()
        }
        XCTAssertTrue(coordinator.canRefreshUsage)

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

    @MainActor
    func testFollowingCommandsMapEventsAndStopBeforePanelAndBridge() async {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let service = FakeUsageService(
            panelStopped: { panel.stopCount == 1 && following.stopCount == 1 }
        )
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        XCTAssertEqual(following.startCount, 1)

        following.emit(.stateChanged(.calibrationRequired))
        for _ in 0 ..< 20 where coordinator.windowFollowingState != .calibrationRequired {
            await Task.yield()
        }
        following.emit(.petDiscoveryStateChanged(.found))
        following.emit(.targetSourceChanged(.pet))
        for _ in 0 ..< 20
            where coordinator.petDiscoveryState != .found || coordinator.targetSource != .pet
        {
            await Task.yield()
        }
        coordinator.beginPetFollowingCalibration()
        XCTAssertEqual(following.beginPetCount, 1)
        XCTAssertEqual(coordinator.targetSource, .pet)
        following.emit(.stateChanged(.calibrating))
        following.emit(.setCalibrationEnabled(true))
        for _ in 0 ..< 20 where !panel.isCalibrationEnabled {
            await Task.yield()
        }
        XCTAssertFalse(coordinator.canChangeHaloMode)
        coordinator.finishWindowFollowingCalibration()
        XCTAssertEqual(following.finishCount, 1)

        coordinator.requestTermination()
        await coordinator.waitForShutdown()
        XCTAssertEqual(following.stopCount, 1)
        XCTAssertEqual(panel.stopCount, 1)
        let stoppedInOrder = await service.panelWasStoppedWhenServiceStopped
        XCTAssertTrue(stoppedInOrder)
    }

    @MainActor
    func testCancelCalibrationRestoresCompactClickThroughAndReferencePoint() async {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        let originalReferencePoint = panel.referencePoint
        following.emit(.stateChanged(.calibrating))
        following.emit(.setCalibrationEnabled(true))
        for _ in 0 ..< 20 where !panel.isCalibrationEnabled {
            await Task.yield()
        }
        panel.setReferencePoint(CGPoint(x: 700, y: 500))
        following.eventsOnCancel = [
            .setCalibrationEnabled(false),
            .placeReferencePoint(originalReferencePoint),
            .stateChanged(.following),
        ]

        coordinator.cancelWindowFollowingCalibration()
        for _ in 0 ..< 100
            where panel.isCalibrationEnabled
                || panel.referencePoint != originalReferencePoint
                || coordinator.windowFollowingState != .following
        {
            await Task.yield()
        }

        XCTAssertEqual(following.cancelCount, 1)
        XCTAssertFalse(panel.isCalibrationEnabled)
        XCTAssertEqual(panel.mode, .compact)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.referencePoint, originalReferencePoint)
        XCTAssertEqual(coordinator.windowFollowingState, .following)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testCalibrationBlocksUnrelatedCoordinatorCommandsAndReset() async {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        following.emit(.stateChanged(.calibrating))
        following.emit(.petDiscoveryStateChanged(.found))
        following.emit(.targetSourceChanged(.pet))
        for _ in 0 ..< 20 where coordinator.windowFollowingState != .calibrating {
            await Task.yield()
        }

        XCTAssertFalse(coordinator.canEnablePetFollowing)
        XCTAssertFalse(coordinator.canUseWindowFallback)
        XCTAssertFalse(coordinator.canResetPetPosition)
        XCTAssertFalse(coordinator.canCalibratePetFollowing)
        XCTAssertFalse(coordinator.canCalibrateWindowFallback)
        coordinator.enablePetFollowing()
        coordinator.useWindowFallback()
        coordinator.resetPetPosition()
        coordinator.beginPetFollowingCalibration()
        coordinator.beginWindowFallbackCalibration()

        XCTAssertEqual(following.enableCount, 0)
        XCTAssertEqual(following.useWindowFallbackCount, 0)
        XCTAssertEqual(following.resetCount, 0)
        XCTAssertEqual(following.beginPetCount, 0)
        XCTAssertEqual(following.beginWindowCount, 0)
        XCTAssertEqual(coordinator.windowFollowingState, .calibrating)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testAutomaticAttachmentStatusAndSideSurvivePresentationModeChanges() async {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        let compactLayout = PetAttachmentLayout(
            side: .above,
            referencePoint: CGPoint(x: 648, y: 794),
            panelFrame: CGRect(x: 472, y: 618, width: 176, height: 176)
        )
        following.emit(.targetSourceChanged(.pet))
        following.emit(.petPlacementStatusChanged(.automatic(.above)))
        following.emit(.placePetAttachment(compactLayout))
        for _ in 0 ..< 20 where panel.attachmentLayout != compactLayout {
            await Task.yield()
        }
        XCTAssertEqual(coordinator.petPlacementStatusText, "Pet placement: Automatic Centered")
        XCTAssertEqual(panel.attachmentLayout?.side, .above)

        coordinator.setHaloMode(.expanded)
        XCTAssertEqual(following.presentationTransitionCount, 2)
        let expandedLayout = PetAttachmentLayout(
            side: .above,
            referencePoint: CGPoint(x: 740, y: 1_138),
            panelFrame: CGRect(x: 380, y: 618, width: 360, height: 520)
        )
        following.emit(.placePetAttachment(expandedLayout))
        for _ in 0 ..< 20 where panel.attachmentLayout != expandedLayout {
            await Task.yield()
        }
        XCTAssertEqual(panel.mode, .expanded)
        XCTAssertEqual(panel.attachmentLayout?.side, .above)
        XCTAssertEqual(panel.referencePoint, expandedLayout.referencePoint)

        coordinator.setHaloMode(.compact)
        XCTAssertEqual(following.presentationTransitionCount, 4)
        XCTAssertTrue(panel.ignoresMouseEvents)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }
}
