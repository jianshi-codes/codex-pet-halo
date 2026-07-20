import CoreGraphics
import XCTest
@testable import PetHalo

@MainActor
private final class FakePermissionProvider: AccessibilityPermissionProviding {
    var current: WindowFollowingPermissionState
    var requested: WindowFollowingPermissionState
    private(set) var requestCount = 0

    init(
        current: WindowFollowingPermissionState,
        requested: WindowFollowingPermissionState? = nil
    ) {
        self.current = current
        self.requested = requested ?? current
    }

    func state() -> WindowFollowingPermissionState { current }
    func request() -> WindowFollowingPermissionState {
        requestCount += 1
        current = requested
        return requested
    }
}

@MainActor
private final class FakeApplicationLocator: CodexApplicationLocating {
    var selection: CodexApplicationSelection
    private(set) var locateCount = 0

    init(_ selection: CodexApplicationSelection) {
        self.selection = selection
    }

    func locate() -> CodexApplicationSelection {
        locateCount += 1
        return selection
    }
}

@MainActor
private final class FakeWindowAccessor: CodexWindowAccessing {
    var result: CodexWindowAccessResult
    var frame: CGRect?
    private(set) var resolveCount = 0
    private(set) var stopCount = 0
    private var generation = 0
    private var handler: (@MainActor (CodexWindowObservationEvent, Int) -> Void)?

    init(result: CodexWindowAccessResult) {
        self.result = result
        if case let .selected(frame) = result {
            self.frame = frame
        }
    }

    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (CodexWindowObservationEvent, Int) -> Void
    ) -> CodexWindowAccessResult {
        resolveCount += 1
        self.generation = generation
        handler = onEvent
        if case let .selected(frame) = result {
            self.frame = frame
        }
        return result
    }

    func currentFrame() -> CGRect? { frame }
    func stop() { stopCount += 1 }

    func emit(_ event: CodexWindowObservationEvent, generation: Int? = nil) {
        handler?(event, generation ?? self.generation)
    }
}

@MainActor
private final class FakePetAccessor: PetTargetAccessing {
    var result: PetTargetAccessResult
    var snapshot: PetTargetSnapshot?
    private(set) var resolveCount = 0
    private(set) var stopCount = 0
    private var generation = 0
    private var handler: (@MainActor (PetTargetObservationEvent, Int) -> Void)?

    init(result: PetTargetAccessResult) {
        self.result = result
        if case let .selected(snapshot) = result {
            self.snapshot = snapshot
        }
    }

    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (PetTargetObservationEvent, Int) -> Void
    ) -> PetTargetAccessResult {
        resolveCount += 1
        self.generation = generation
        handler = onEvent
        if case let .selected(snapshot) = result {
            self.snapshot = PetTargetSnapshot(generation: generation, frame: snapshot.frame)
            return .selected(self.snapshot!)
        }
        return result
    }

    func currentSnapshot() -> PetTargetSnapshot? { snapshot }
    func stop() { stopCount += 1 }

    func emit(_ event: PetTargetObservationEvent, generation: Int? = nil) {
        handler?(event, generation ?? self.generation)
    }
}

@MainActor
private final class FakeSystemEventSource: WindowFollowingSystemEventSourcing {
    private let stream: AsyncStream<WindowFollowingSystemEvent>
    private let continuation: AsyncStream<WindowFollowingSystemEvent>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        let pair = AsyncStream.makeStream(
            of: WindowFollowingSystemEvent.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func events() -> AsyncStream<WindowFollowingSystemEvent> { stream }
    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func emit(_ event: WindowFollowingSystemEvent) { continuation.yield(event) }
}

@MainActor
private final class FakeFollowingPreferences: WindowFollowingPreferenceStoring {
    var snapshot: WindowFollowingPreferenceSnapshot
    private(set) var enabledWrites: [Bool] = []
    private(set) var windowAnchorWrites: [HaloWindowAnchor?] = []
    private(set) var petAnchorWrites: [PetRelativeAnchor?] = []

    init(
        enabled: Bool,
        windowAnchor: HaloWindowAnchor? = nil,
        petAnchor: PetRelativeAnchor? = nil
    ) {
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            windowAnchor: windowAnchor,
            petAnchor: petAnchor
        )
    }

    func load() -> WindowFollowingPreferenceSnapshot { snapshot }
    func setFollowingEnabled(_ enabled: Bool) {
        enabledWrites.append(enabled)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            windowAnchor: snapshot.windowAnchor,
            petAnchor: snapshot.petAnchor
        )
    }
    func setWindowAnchor(_ anchor: HaloWindowAnchor?) {
        windowAnchorWrites.append(anchor)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: snapshot.followingEnabled,
            windowAnchor: anchor,
            petAnchor: snapshot.petAnchor
        )
    }
    func setPetAnchor(_ anchor: PetRelativeAnchor?) {
        petAnchorWrites.append(anchor)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: snapshot.followingEnabled,
            windowAnchor: snapshot.windowAnchor,
            petAnchor: anchor
        )
    }
}

@MainActor
private final class FollowingEventRecorder {
    private(set) var events: [HaloWindowFollowingEvent] = []
    private var task: Task<Void, Never>?

    func start(_ stream: AsyncStream<HaloWindowFollowingEvent>) {
        task = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                events.append(event)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

final class WindowFollowingServiceTests: XCTestCase {
    @MainActor
    func testStartupNeverPromptsAndKeepsFreeFloatingWithoutPermission() async {
        let permission = FakePermissionProvider(current: .notGranted, requested: .granted)
        let context = makeContext(permission: permission, enabled: true)

        context.service.start()

        XCTAssertEqual(context.service.state, .permissionRequired)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertEqual(context.accessor.resolveCount, 0)
        await context.service.stop()
        XCTAssertEqual(context.events.stopCount, 1)
    }

    @MainActor
    func testExplicitEnableRequestsPermissionAndRequiresCalibration() async {
        let permission = FakePermissionProvider(current: .notGranted, requested: .granted)
        let context = makeContext(permission: permission)
        context.service.start()

        context.service.enable()

        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertEqual(context.service.state, .calibrationRequired)
        XCTAssertEqual(context.preferences.enabledWrites, [true])
        await context.service.stop()
    }

    @MainActor
    func testCalibrationDoesNotPersistUntilFinishAndCancelRestoresState() async {
        let context = makeContext(enabled: true)
        context.service.start()
        context.service.beginWindowCalibration(currentReferencePoint: CGPoint(x: 300, y: 400))
        XCTAssertEqual(context.service.state, .calibrating)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)

        context.service.cancelCalibration()
        XCTAssertEqual(context.service.state, .calibrationRequired)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)

        context.service.beginWindowCalibration(currentReferencePoint: CGPoint(x: 300, y: 400))
        context.service.finishCalibration(currentReferencePoint: CGPoint(x: 950, y: 700))
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.preferences.windowAnchorWrites.count, 1)
        XCTAssertTrue(context.preferences.snapshot.windowAnchor?.isValid == true)
        await context.service.stop()
    }

    @MainActor
    func testCancellingWindowCalibrationCleansUpOnceAndRestoresSuppression() async {
        let originalReferencePoint = CGPoint(x: 900, y: 700)
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true,
            anchor: windowAnchor,
            petAnchor: petAnchor
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        context.service.useWindowFallback()
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)

        context.service.beginWindowCalibration(currentReferencePoint: originalReferencePoint)
        for _ in 0 ..< 100 where !recorder.events.contains(.setCalibrationEnabled(true)) {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .calibrating)
        XCTAssertEqual(
            recorder.events.filter { $0 == .setCalibrationEnabled(true) }.count,
            1
        )
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        XCTAssertTrue(context.preferences.petAnchorWrites.isEmpty)
        let eventCountBeforeCancel = recorder.events.count

        context.service.cancelCalibration()
        for _ in 0 ..< 100
            where context.service.state == .calibrating
                || !recorder.events.dropFirst(eventCountBeforeCancel).contains(.setCalibrationEnabled(false))
                || !recorder.events.dropFirst(eventCountBeforeCancel).contains(.stateChanged(.following))
        {
            await Task.yield()
        }

        let cancelEvents = Array(recorder.events.dropFirst(eventCountBeforeCancel))
        XCTAssertEqual(
            cancelEvents.filter { $0 == .setCalibrationEnabled(false) }.count,
            1
        )
        XCTAssertEqual(
            cancelEvents.filter { $0 == .placeReferencePoint(originalReferencePoint) }.count,
            1
        )
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        XCTAssertTrue(context.preferences.petAnchorWrites.isEmpty)

        let eventCountAfterCancel = recorder.events.count
        context.service.cancelCalibration()
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(recorder.events.count, eventCountAfterCancel)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        XCTAssertTrue(context.preferences.petAnchorWrites.isEmpty)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testResetAndUnrelatedCommandsAreNoOpDuringCalibration() async {
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let petSnapshot = PetTargetSnapshot(
            generation: 0,
            frame: CGRect(x: 500, y: 300, width: 120, height: 110)
        )
        let petContext = makeContext(
            petAccessResult: .selected(petSnapshot),
            enabled: true,
            petAnchor: petAnchor
        )
        petContext.service.start()
        petContext.service.beginPetCalibration(currentReferencePoint: CGPoint(x: 600, y: 400))
        XCTAssertEqual(petContext.service.state, .calibrating)

        petContext.service.enable()
        petContext.service.useWindowFallback()
        petContext.service.resetPetPosition()
        petContext.service.beginPetCalibration(currentReferencePoint: .zero)
        petContext.service.beginWindowCalibration(currentReferencePoint: .zero)

        XCTAssertEqual(petContext.service.state, .calibrating)
        XCTAssertEqual(petContext.preferences.snapshot.petAnchor, petAnchor)
        XCTAssertTrue(petContext.preferences.petAnchorWrites.isEmpty)
        petContext.service.cancelCalibration()
        await petContext.service.stop()

        let windowContext = makeContext(
            petAccessResult: .selected(petSnapshot),
            enabled: true,
            petAnchor: petAnchor
        )
        windowContext.service.start()
        windowContext.service.beginWindowCalibration(
            currentReferencePoint: CGPoint(x: 900, y: 700)
        )
        XCTAssertEqual(windowContext.service.state, .calibrating)

        windowContext.service.resetPetPosition()

        XCTAssertEqual(windowContext.service.state, .calibrating)
        XCTAssertEqual(windowContext.preferences.snapshot.petAnchor, petAnchor)
        XCTAssertTrue(windowContext.preferences.petAnchorWrites.isEmpty)
        windowContext.service.cancelCalibration()
        await windowContext.service.stop()
    }

    @MainActor
    func testMoveResizeUsesPersistedAnchorAndStaleGenerationIsIgnored() async {
        let anchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 20, height: 20)
        )
        let context = makeContext(enabled: true, anchor: anchor)
        context.service.start()
        XCTAssertEqual(context.service.state, .following)
        let initialResolveCount = context.accessor.resolveCount

        context.accessor.frame = CGRect(x: 200, y: 300, width: 1_000, height: 700)
        context.accessor.emit(.geometryChanged)
        XCTAssertEqual(context.service.state, .following)

        context.accessor.emit(.selectionChanged, generation: -1)
        XCTAssertEqual(context.accessor.resolveCount, initialResolveCount)
        await context.service.stop()
    }

    @MainActor
    func testAmbiguityAbsenceAndObserverFailureRemainSafeFallbacks() async {
        let permission = FakePermissionProvider(current: .granted)
        let processAmbiguous = makeContext(
            permission: permission,
            locatorSelection: .ambiguous,
            enabled: true
        )
        processAmbiguous.service.start()
        XCTAssertEqual(processAmbiguous.service.state, .unavailable(.processAmbiguous))
        await processAmbiguous.service.stop()

        let observerFailed = makeContext(
            permission: permission,
            accessResult: .observerFailed,
            enabled: true
        )
        observerFailed.service.start()
        XCTAssertEqual(observerFailed.service.state, .suspended(.observerFailed))
        await observerFailed.service.stop()
    }

    @MainActor
    func testTemporaryCodexLossPreservesCalibrationAndRelaunchResumes() async {
        let anchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(enabled: true, anchor: anchor)
        context.service.start()
        context.locator.selection = .unavailable
        context.events.emit(.codexEnvironmentChanged)
        for _ in 0 ..< 20 where context.service.state != .unavailable(.codexUnavailable) {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .unavailable(.codexUnavailable))
        XCTAssertEqual(context.preferences.snapshot.windowAnchor, anchor)

        context.locator.selection = .selected(processIdentifier: 42)
        context.events.emit(.codexEnvironmentChanged)
        for _ in 0 ..< 20 where context.service.state != .following {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .following)
        await context.service.stop()
    }

    @MainActor
    func testRelaunchRecoversWhenCodexWindowBecomesAvailableAfterLaunchEvent() async {
        let anchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(enabled: true, anchor: anchor)
        context.service.start()

        context.locator.selection = .unavailable
        context.events.emit(.codexEnvironmentChanged)
        for _ in 0 ..< 20 where context.service.state != .unavailable(.codexUnavailable) {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .unavailable(.codexUnavailable))

        context.locator.selection = .selected(processIdentifier: 42)
        context.accessor.result = .unavailable
        context.events.emit(.codexEnvironmentChanged)
        for _ in 0 ..< 20 where context.service.state != .suspended(.windowUnavailable) {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .suspended(.windowUnavailable))

        context.accessor.result = .selected(
            frame: CGRect(x: 200, y: 300, width: 1_000, height: 700)
        )
        context.service.recoverStateIfNeeded()

        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.preferences.snapshot.windowAnchor, anchor)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        await context.service.stop()
    }

    @MainActor
    func testDisableResetAndRepeatedCommandsAreIdempotent() async {
        let context = makeContext(enabled: true)
        context.service.start()
        context.service.disable()
        context.service.disable()
        XCTAssertEqual(context.preferences.enabledWrites, [false])
        XCTAssertEqual(context.service.state, .disabled)

        context.service.resetPetPosition()
        XCTAssertEqual(context.preferences.petAnchorWrites, [nil])
        XCTAssertNil(context.preferences.snapshot.petAnchor)
        XCTAssertEqual(context.preferences.enabledWrites, [false])
        await context.service.stop()
    }

    @MainActor
    func testStopInvalidatesCallbacksAndCleansObserversExactlyOnce() async {
        let anchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        let context = makeContext(enabled: true, anchor: anchor)
        context.service.start()
        await context.service.stop()
        await context.service.stop()
        let state = context.service.state
        context.accessor.emit(.targetInvalidated)

        XCTAssertEqual(context.service.state, state)
        XCTAssertEqual(context.events.stopCount, 1)
    }

    @MainActor
    func testPetIsPreferredOverWindowFallback() async {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 20, height: 20)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true,
            anchor: HaloWindowAnchor(
                version: 1,
                normalizedWindowPoint: UnitPointValue(x: 1, y: 1),
                pointOffset: PointOffsetValue(width: 10, height: 10)
            ),
            petAnchor: petAnchor
        )

        context.service.start()

        XCTAssertEqual(context.service.petDiscoveryState, .found)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.accessor.resolveCount, 0)
        await context.service.stop()
    }

    @MainActor
    func testPetLossFallsBackAndRecoveryResumesWithoutRecalibration() async {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 20, height: 20)
        )
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true,
            anchor: windowAnchor,
            petAnchor: petAnchor
        )
        context.service.start()
        XCTAssertEqual(context.service.targetSource, .pet)

        context.petAccessor.result = .unavailable
        context.petAccessor.snapshot = nil
        context.petAccessor.emit(.targetInvalidated)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.service.petDiscoveryState, .unavailable)

        context.petAccessor.result = .selected(PetTargetSnapshot(generation: 0, frame: petFrame))
        context.accessor.emit(.selectionChanged)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.preferences.snapshot.petAnchor, petAnchor)
        XCTAssertTrue(context.preferences.petAnchorWrites.isEmpty)
        await context.service.stop()
    }

    @MainActor
    func testPetAmbiguityNeverGuessesAndUsesWindowFallback() async {
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        let context = makeContext(
            petAccessResult: .ambiguous,
            enabled: true,
            anchor: windowAnchor
        )

        context.service.start()

        XCTAssertEqual(context.service.petDiscoveryState, .ambiguous)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.service.state, .following)
        await context.service.stop()
    }

    @MainActor
    func testBothTargetsUnavailableLeavesSafeFreeFloatingFallback() async {
        let context = makeContext(
            petAccessResult: .unavailable,
            accessResult: .unavailable,
            enabled: true
        )

        context.service.start()

        XCTAssertEqual(context.service.petDiscoveryState, .unavailable)
        XCTAssertEqual(context.service.targetSource, .freeFloating)
        XCTAssertEqual(context.service.state, .suspended(.windowUnavailable))
        await context.service.stop()
    }

    @MainActor
    func testPetMoveResizeUsesPetGenerationAndNeverResolvesStationaryWindow() async {
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 1, y: 1),
            pointOffset: PointOffsetValue(width: 20, height: 20)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true,
            petAnchor: petAnchor
        )
        context.service.start()
        let petResolveCount = context.petAccessor.resolveCount

        context.petAccessor.snapshot = PetTargetSnapshot(
            generation: 1,
            frame: CGRect(x: -420, y: -180, width: 150, height: 130)
        )
        context.petAccessor.emit(.geometryChanged)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.accessor.resolveCount, 0)

        context.petAccessor.emit(.selectionChanged, generation: -1)
        XCTAssertEqual(context.petAccessor.resolveCount, petResolveCount)
        XCTAssertEqual(context.service.targetSource, .pet)
        await context.service.stop()
    }

    @MainActor
    func testPetCalibrationPersistsSeparatelyAndResetPreservesWindowAnchor() async {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true,
            anchor: windowAnchor
        )
        context.service.start()
        XCTAssertEqual(context.service.state, .calibrationRequired)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)

        context.service.beginPetCalibration(currentReferencePoint: CGPoint(x: 600, y: 400))
        context.service.finishCalibration(currentReferencePoint: CGPoint(x: 650, y: 430))
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertTrue(context.preferences.snapshot.petAnchor?.isValid == true)
        XCTAssertEqual(context.preferences.snapshot.windowAnchor, windowAnchor)

        context.service.resetPetPosition()
        XCTAssertNil(context.preferences.snapshot.petAnchor)
        XCTAssertEqual(context.preferences.snapshot.windowAnchor, windowAnchor)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        await context.service.stop()
    }

    @MainActor
    func testActivityWindowChangesDoNotCancelValidPetCalibration() async {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true,
            anchor: windowAnchor
        )
        context.service.start()
        context.service.beginPetCalibration(currentReferencePoint: CGPoint(x: 600, y: 400))
        XCTAssertEqual(context.service.state, .calibrating)

        context.petAccessor.emit(.selectionChanged)
        context.petAccessor.emit(.targetInvalidated)
        context.service.recoverStateIfNeeded()

        XCTAssertEqual(context.service.state, .calibrating)
        XCTAssertTrue(context.preferences.petAnchorWrites.isEmpty)
        context.service.finishCalibration(currentReferencePoint: CGPoint(x: 650, y: 430))
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.state, .following)
        await context.service.stop()
    }

    @MainActor
    func testWindowFallbackCalibrationReturnsToPetPreference() async {
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true,
            petAnchor: petAnchor
        )
        context.service.start()
        XCTAssertEqual(context.service.targetSource, .pet)

        context.service.beginWindowCalibration(currentReferencePoint: CGPoint(x: 600, y: 400))
        context.service.finishCalibration(currentReferencePoint: CGPoint(x: 900, y: 700))

        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertTrue(context.preferences.snapshot.windowAnchor?.isValid == true)
        XCTAssertEqual(context.preferences.snapshot.petAnchor, petAnchor)
        await context.service.stop()
    }

    @MainActor
    func testExplicitWindowFallbackDoesNotChurnObserversOnRecoveryTick() async {
        let petAnchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 10, height: 10)
        )
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true,
            anchor: windowAnchor,
            petAnchor: petAnchor
        )
        context.service.start()
        context.service.useWindowFallback()
        let petResolveCount = context.petAccessor.resolveCount
        let windowResolveCount = context.accessor.resolveCount

        context.service.recoverStateIfNeeded()

        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.petAccessor.resolveCount, petResolveCount)
        XCTAssertEqual(context.accessor.resolveCount, windowResolveCount)
        await context.service.stop()
    }

    @MainActor
    private func makeContext(
        permission: FakePermissionProvider = FakePermissionProvider(current: .granted),
        locatorSelection: CodexApplicationSelection = .selected(processIdentifier: 42),
        petAccessResult: PetTargetAccessResult = .unavailable,
        accessResult: CodexWindowAccessResult = .selected(
            frame: CGRect(x: 100, y: 200, width: 800, height: 600)
        ),
        enabled: Bool = false,
        anchor: HaloWindowAnchor? = nil,
        petAnchor: PetRelativeAnchor? = nil
    ) -> Context {
        let locator = FakeApplicationLocator(locatorSelection)
        let petAccessor = FakePetAccessor(result: petAccessResult)
        let accessor = FakeWindowAccessor(result: accessResult)
        let events = FakeSystemEventSource()
        let preferences = FakeFollowingPreferences(
            enabled: enabled,
            windowAnchor: anchor,
            petAnchor: petAnchor
        )
        let service = WindowFollowingService(
            permissionProvider: permission,
            applicationLocator: locator,
            petAccessor: petAccessor,
            windowAccessor: accessor,
            systemEvents: events,
            preferences: preferences
        )
        return Context(
            service: service,
            locator: locator,
            petAccessor: petAccessor,
            accessor: accessor,
            events: events,
            preferences: preferences
        )
    }

    @MainActor
    private struct Context {
        let service: WindowFollowingService
        let locator: FakeApplicationLocator
        let petAccessor: FakePetAccessor
        let accessor: FakeWindowAccessor
        let events: FakeSystemEventSource
        let preferences: FakeFollowingPreferences
    }
}
