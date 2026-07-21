import XCTest
import PetHaloCore
@testable import PetHalo

private enum FakePanelOperation: Equatable {
    case setSurfaceMode(HaloSurfaceMode)
    case setAttachment(PetAttachmentLayout, surfaceMode: HaloSurfaceMode)
}

@MainActor
private final class FakeHaloPanelController: HaloPanelControlling {
    private(set) var isVisible = false
    private(set) var mode: HaloPresentationMode = .compact
    private(set) var surfaceMode: HaloSurfaceMode = .compactCard
    private(set) var frame = CGRect(x: 100, y: 100, width: 176, height: 176)
    private(set) var isCalibrationEnabled = false
    private(set) var attachmentLayout: PetAttachmentLayout?
    private(set) var ignoresMouseEvents = true
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var stopCount = 0
    private(set) var models: [HaloPresentationModel] = []
    private(set) var petRingModels: [PetRingPresentationModel] = []
    private(set) var petRingOrientation: PetRingOrientation = .fixedDefault
    private(set) var petRingLabelSide: PetRingLabelSide = .right
    private(set) var operations: [FakePanelOperation] = []
    private(set) var lastSetReferencePoint: CGPoint?
    var onSetAttachment: (@MainActor (PetAttachmentLayout) -> Void)?
    var petAttachmentSampler: (@MainActor () -> PetAttachmentLayout?)?
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
        setSurfaceMode(HaloSurfaceMode(cardMode: mode))
    }

    func setSurfaceMode(_ mode: HaloSurfaceMode) {
        guard !stopped else { return }
        surfaceMode = mode
        if let cardMode = mode.cardMode {
            self.mode = cardMode
        } else {
            isCalibrationEnabled = false
        }
        frame.size = HaloPanelController.size(for: mode)
        ignoresMouseEvents = mode == .petRing
            || (!isCalibrationEnabled && mode == .compactCard)
        operations.append(.setSurfaceMode(mode))
    }

    func setReferencePoint(_ referencePoint: CGPoint) {
        guard !stopped else { return }
        attachmentLayout = nil
        lastSetReferencePoint = referencePoint
        frame = HaloPlacementGeometry.frame(referencePoint: referencePoint, size: frame.size)
    }

    func setAttachmentLayout(_ layout: PetAttachmentLayout) {
        guard !stopped else { return }
        attachmentLayout = layout
        frame = layout.panelFrame
        operations.append(.setAttachment(layout, surfaceMode: surfaceMode))
        onSetAttachment?(layout)
    }

    func followAttachmentLayout(_ layout: PetAttachmentLayout) {
        setAttachmentLayout(layout)
    }

    func setPetAttachmentSampler(
        _ sampler: @escaping @MainActor () -> PetAttachmentLayout?
    ) {
        petAttachmentSampler = sampler
    }

    func setPetRingOrientation(_ orientation: PetRingOrientation) {
        petRingOrientation = orientation
    }

    func setCalibrationEnabled(_ enabled: Bool) {
        guard !stopped else { return }
        isCalibrationEnabled = enabled
        ignoresMouseEvents = enabled ? false : surfaceMode != .expandedCard
    }

    func resetToDefaultPosition() {
        guard !stopped else { return }
        frame.origin = CGPoint(x: 0, y: 0)
    }

    func update(
        cardModel: HaloPresentationModel,
        petRingModel: PetRingPresentationModel
    ) {
        guard !stopped else { return }
        models.append(cardModel)
        petRingModels.append(petRingModel)
    }

    func resetOperations() {
        operations = []
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
    private(set) var resetPetVisualCenterCount = 0
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
    func resetPetVisualCenter() { resetPetVisualCenterCount += 1 }
    func samplePetAttachmentLayout() -> PetAttachmentLayout? { nil }
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
                compatibility: .reviewed(version: "test"),
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
    func testPublicUsageFailureMessagesAreConciseAndSafe() {
        let cases: [(SafeFailureReason, String)] = [
            (.executableMissing, "Usage: Codex CLI not found"),
            (.unsupportedProtocolVersion, "Usage: Unsupported Codex CLI version"),
            (.runtimeIncompatible, "Usage: CLI runtime incompatible"),
            (.authenticationUnavailable, "Usage: Sign in to Codex"),
            (.rateLimitsUnavailable, "Usage: Rate limits temporarily unavailable"),
            (.accountUsageUnavailable, "Usage: Today temporarily unavailable"),
            (.accountUsageUnsupported, "Usage: Today temporarily unavailable"),
            (.transportClosed, "Usage: Temporarily unavailable"),
        ]

        for (failure, expected) in cases {
            let state = CodexUsageState(
                connection: .unavailable,
                compatibility: .unknown,
                snapshot: nil,
                capabilities: .unavailable,
                componentFreshness: .unavailable,
                lastSuccessfulRefresh: nil,
                failureReason: failure
            )
            let message = ApplicationCoordinator.usageStatusText(for: state)
            XCTAssertEqual(message, expected)
            XCTAssertFalse(message.contains("/"))
            XCTAssertFalse(message.contains("{"))
            XCTAssertFalse(message.contains("future"))
        }
    }

    @MainActor
    func testCLIStatusDistinguishesReviewedProvisionalBlockedAndRuntimeIncompatible() {
        XCTAssertEqual(
            ApplicationCoordinator.cliStatusText(for: .reviewed(version: "0.145.0-alpha.18")),
            "CLI: 0.145.0-alpha.18"
        )
        XCTAssertEqual(
            ApplicationCoordinator.cliStatusText(for: .provisional(version: "0.145.0-alpha.27")),
            "CLI: 0.145.0-alpha.27 · provisional"
        )
        XCTAssertEqual(
            ApplicationCoordinator.cliStatusText(for: .blocked(version: nil)),
            "CLI: blocked"
        )
        XCTAssertEqual(
            ApplicationCoordinator.cliStatusText(
                for: .runtimeIncompatible(version: "0.145.0-alpha.27")
            ),
            "CLI: 0.145.0-alpha.27 · incompatible"
        )
    }

    @MainActor
    func testFollowingFailureMessagesMatchPublicTroubleshootingStates() {
        XCTAssertEqual(
            WindowFollowingState.permissionRequired.statusText,
            "Following: Accessibility Required"
        )
        XCTAssertEqual(
            WindowFollowingState.unavailable(.codexUnavailable).statusText,
            "Following: Codex Not Running"
        )
        XCTAssertEqual(
            WindowFollowingState.unavailable(.windowAmbiguous).statusText,
            "Following: Target Ambiguous"
        )
    }

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
        for _ in 0 ..< 100 where coordinator.bridgeStatusText != "Usage: Connected" {
            await Task.yield()
        }

        XCTAssertEqual(coordinator.bridgeStatusText, "Usage: Connected")
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
        XCTAssertEqual(panel.showCount, 0)
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
            compatibility: .blocked(version: "future"),
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
        XCTAssertEqual(coordinator.bridgeStatusText, "Usage: Temporarily unavailable")
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
        for _ in 0 ..< 100 where coordinator.bridgeStatusText != "Usage: Connected" {
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
                compatibility: .reviewed(version: "test"),
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
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        XCTAssertFalse(coordinator.canRefreshUsage)
        coordinator.refreshUsage()
        let disconnectedRefreshCount = await service.refreshCount
        XCTAssertEqual(disconnectedRefreshCount, 0)
        coordinator.start()

        following.emit(.targetSourceChanged(.codexWindowFallback))
        for _ in 0 ..< 100 where coordinator.targetSource != .codexWindowFallback {
            await Task.yield()
        }
        XCTAssertFalse(coordinator.haloIsVisible)
        coordinator.useWindowFallback()
        XCTAssertTrue(coordinator.haloIsVisible)

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
    func testRuntimeIncompatibleStateKeepsManualRefreshAvailable() async {
        let service = FakeUsageService()
        let coordinator = ApplicationCoordinator(
            usageService: service,
            haloPanelController: FakeHaloPanelController(),
            terminateApplication: {}
        )
        coordinator.start()
        await service.emit(
            CodexUsageState(
                connection: .unavailable,
                compatibility: .runtimeIncompatible(version: "0.145.0-alpha.27"),
                snapshot: nil,
                capabilities: .unavailable,
                componentFreshness: .unavailable,
                lastSuccessfulRefresh: nil,
                failureReason: .runtimeIncompatible
            )
        )
        for _ in 0 ..< 100 where coordinator.bridgeStatusText != "Usage: CLI runtime incompatible" {
            await Task.yield()
        }

        XCTAssertTrue(coordinator.canRefreshUsage)
        coordinator.refreshUsage()
        await coordinator.waitForRefresh()
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
    func testWindowCalibrationBlocksUnrelatedCoordinatorCommands() async {
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
        XCTAssertFalse(coordinator.canCalibrateWindowFallback)
        coordinator.enablePetFollowing()
        coordinator.useWindowFallback()
        coordinator.beginWindowFallbackCalibration()

        XCTAssertEqual(following.enableCount, 0)
        XCTAssertEqual(following.useWindowFallbackCount, 0)
        XCTAssertEqual(following.beginWindowCount, 0)
        XCTAssertEqual(coordinator.windowFollowingState, .calibrating)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testExpandedFallbackRecoversToAtomicPetRingAttachmentAndRestoresMode() async throws {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        following.emit(.targetSourceChanged(.codexWindowFallback))
        for _ in 0 ..< 100 where coordinator.targetSource != .codexWindowFallback {
            await Task.yield()
        }
        XCTAssertFalse(coordinator.haloIsVisible)
        coordinator.useWindowFallback()
        XCTAssertTrue(coordinator.haloIsVisible)
        coordinator.setHaloMode(.expanded)
        XCTAssertEqual(panel.mode, .expanded)
        XCTAssertEqual(panel.frame.size, CGSize(width: 360, height: 520))

        let petFrame = CGRect(x: 500, y: 600, width: 120, height: 110)
        let compactLayout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petFrame,
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize
        ))
        panel.resetOperations()
        panel.onSetAttachment = { _ in
            XCTAssertEqual(coordinator.targetSource, .pet)
            XCTAssertEqual(coordinator.haloSurfaceMode, .petRing)
        }
        following.emit(.activatePetAttachment(compactLayout))
        following.emit(.petPlacementStatusChanged(.centered))
        for _ in 0 ..< 100
            where panel.attachmentLayout != compactLayout
                || panel.surfaceMode != .petRing
                || coordinator.petPlacementStatus != .centered
        {
            await Task.yield()
        }
        XCTAssertEqual(
            panel.operations,
            [
                .setSurfaceMode(.petRing),
                .setAttachment(compactLayout, surfaceMode: .petRing),
            ]
        )
        XCTAssertFalse(panel.operations.contains { operation in
            if case let .setAttachment(layout, surfaceMode) = operation {
                return surfaceMode == .expandedCard
                    || layout.panelFrame.size == CGSize(width: 360, height: 520)
            }
            return false
        })
        XCTAssertEqual(coordinator.petPlacementStatusText, "Pet placement: Centered")
        XCTAssertEqual(coordinator.targetSource, .pet)
        XCTAssertEqual(panel.surfaceMode, .petRing)
        XCTAssertEqual(panel.frame.size, PetAttachmentLayoutPolicy.petAttachmentSize)
        XCTAssertEqual(panel.frame.midX, petFrame.midX)
        XCTAssertEqual(panel.frame.midY, petFrame.midY)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(coordinator.haloIsVisible)
        XCTAssertFalse(coordinator.canChangeHaloMode)

        coordinator.setHaloMode(.expanded)
        XCTAssertEqual(panel.surfaceMode, .petRing)

        following.emit(.targetSourceChanged(.codexWindowFallback))
        for _ in 0 ..< 100 where panel.surfaceMode != .expandedCard {
            await Task.yield()
        }
        XCTAssertEqual(panel.mode, .expanded)
        XCTAssertEqual(panel.surfaceMode, .expandedCard)
        XCTAssertFalse(coordinator.haloIsVisible)
        XCTAssertTrue(coordinator.canChangeHaloMode)
        coordinator.setHaloMode(.compact)
        XCTAssertEqual(panel.mode, .compact)
        XCTAssertTrue(panel.ignoresMouseEvents)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testFreeFloatingPetLossRestoresPrePetReferenceBeforeExpandedCard() async throws {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        coordinator.setHaloMode(.expanded)
        let fallbackReference = panel.referencePoint
        let petLayout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: CGRect(x: 700, y: 500, width: 120, height: 110),
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize
        ))

        following.emit(.activatePetAttachment(petLayout))
        for _ in 0 ..< 100 where panel.surfaceMode != .petRing {
            await Task.yield()
        }
        following.emit(.targetSourceChanged(.freeFloating))
        for _ in 0 ..< 100 where panel.surfaceMode != .expandedCard {
            await Task.yield()
        }

        XCTAssertEqual(panel.lastSetReferencePoint, fallbackReference)
        XCTAssertEqual(panel.surfaceMode, .expandedCard)
        XCTAssertEqual(panel.frame.size, HaloPanelController.expandedSize)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertFalse(coordinator.haloIsVisible)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }

    @MainActor
    func testPetCenterAdjustmentAndOrientationPreviewPreservePetSurface() async throws {
        let panel = FakeHaloPanelController()
        let following = FakeWindowFollowingService()
        let coordinator = ApplicationCoordinator(
            usageService: FakeUsageService(),
            haloPanelController: panel,
            windowFollowingService: following,
            terminateApplication: {}
        )
        coordinator.start()
        let layout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: CGRect(x: 500, y: 300, width: 120, height: 110),
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize
        ))
        following.emit(.petDiscoveryStateChanged(.found))
        following.emit(.activatePetAttachment(layout))
        for _ in 0 ..< 100 where panel.surfaceMode != .petRing {
            await Task.yield()
        }
        coordinator.beginPetFollowingCalibration()
        following.emit(.stateChanged(.calibrating))
        following.emit(.setCalibrationEnabled(true))
        for _ in 0 ..< 100
            where !coordinator.isAdjustingPetRingCenter || panel.ignoresMouseEvents
        {
            await Task.yield()
        }
        XCTAssertFalse(panel.ignoresMouseEvents)

        coordinator.nudgePetRing(horizontal: 4, vertical: -4)
        let adjustedFrame = panel.frame
        XCTAssertEqual(adjustedFrame.origin, CGPoint(x: layout.panelFrame.minX + 4, y: layout.panelFrame.minY - 4))
        coordinator.finishWindowFollowingCalibration()
        following.emit(.setCalibrationEnabled(false))
        following.emit(.stateChanged(.following))
        following.emit(.petRingOrientationChanged(.openingBottom))
        for _ in 0 ..< 100 where panel.petRingOrientation != .openingBottom {
            await Task.yield()
        }

        XCTAssertEqual(following.beginPetCount, 1)
        XCTAssertEqual(following.finishCount, 1)
        XCTAssertEqual(panel.petRingOrientation, .openingBottom)
        XCTAssertEqual(panel.frame, adjustedFrame)
        XCTAssertEqual(panel.surfaceMode, .petRing)
        XCTAssertTrue(panel.ignoresMouseEvents)
        coordinator.resetPetVisualCenter()
        XCTAssertEqual(following.resetPetVisualCenterCount, 1)

        #if DEBUG
        let frameBeforePreview = panel.frame
        coordinator.setPetRingOrientationPreview(.forceGapAbove)
        XCTAssertEqual(panel.petRingOrientation, .openingTop)
        XCTAssertEqual(panel.frame, frameBeforePreview)
        coordinator.setPetRingOrientationPreview(.forceGapBelow)
        XCTAssertEqual(panel.petRingOrientation, .openingBottom)
        XCTAssertEqual(panel.frame, frameBeforePreview)
        #endif

        coordinator.setHaloMode(.expanded)
        XCTAssertEqual(panel.surfaceMode, .petRing)
        coordinator.requestTermination()
        await coordinator.waitForShutdown()
    }
}
