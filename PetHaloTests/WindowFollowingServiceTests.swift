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
    private(set) var anchorWrites: [HaloWindowAnchor?] = []

    init(enabled: Bool, anchor: HaloWindowAnchor? = nil) {
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            anchor: anchor
        )
    }

    func load() -> WindowFollowingPreferenceSnapshot { snapshot }
    func setFollowingEnabled(_ enabled: Bool) {
        enabledWrites.append(enabled)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            anchor: snapshot.anchor
        )
    }
    func setAnchor(_ anchor: HaloWindowAnchor?) {
        anchorWrites.append(anchor)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: snapshot.followingEnabled,
            anchor: anchor
        )
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
        context.service.beginCalibration(currentReferencePoint: CGPoint(x: 300, y: 400))
        XCTAssertEqual(context.service.state, .calibrating)
        XCTAssertTrue(context.preferences.anchorWrites.isEmpty)

        context.service.cancelCalibration()
        XCTAssertEqual(context.service.state, .calibrationRequired)
        XCTAssertTrue(context.preferences.anchorWrites.isEmpty)

        context.service.beginCalibration(currentReferencePoint: CGPoint(x: 300, y: 400))
        context.service.finishCalibration(currentReferencePoint: CGPoint(x: 950, y: 700))
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.preferences.anchorWrites.count, 1)
        XCTAssertTrue(context.preferences.snapshot.anchor?.isValid == true)
        await context.service.stop()
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
        XCTAssertEqual(context.preferences.snapshot.anchor, anchor)

        context.locator.selection = .selected(processIdentifier: 42)
        context.events.emit(.codexEnvironmentChanged)
        for _ in 0 ..< 20 where context.service.state != .following {
            await Task.yield()
        }
        XCTAssertEqual(context.service.state, .following)
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

        context.service.resetPosition()
        XCTAssertEqual(context.preferences.anchorWrites, [nil])
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
    private func makeContext(
        permission: FakePermissionProvider = FakePermissionProvider(current: .granted),
        locatorSelection: CodexApplicationSelection = .selected(processIdentifier: 42),
        accessResult: CodexWindowAccessResult = .selected(
            frame: CGRect(x: 100, y: 200, width: 800, height: 600)
        ),
        enabled: Bool = false,
        anchor: HaloWindowAnchor? = nil
    ) -> Context {
        let locator = FakeApplicationLocator(locatorSelection)
        let accessor = FakeWindowAccessor(result: accessResult)
        let events = FakeSystemEventSource()
        let preferences = FakeFollowingPreferences(enabled: enabled, anchor: anchor)
        let service = WindowFollowingService(
            permissionProvider: permission,
            applicationLocator: locator,
            windowAccessor: accessor,
            systemEvents: events,
            preferences: preferences
        )
        return Context(
            service: service,
            locator: locator,
            accessor: accessor,
            events: events,
            preferences: preferences
        )
    }

    @MainActor
    private struct Context {
        let service: WindowFollowingService
        let locator: FakeApplicationLocator
        let accessor: FakeWindowAccessor
        let events: FakeSystemEventSource
        let preferences: FakeFollowingPreferences
    }
}
