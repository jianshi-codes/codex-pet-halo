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
            let current = PetTargetSnapshot(
                generation: generation,
                frame: snapshot.frame,
                activityGeometryHint: snapshot.activityGeometryHint
            )
            self.snapshot = current
            return .selected(current)
        }
        snapshot = nil
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
    private(set) var petVisualCenterOffsetWrites: [PetVisualCenterOffset] = []
    private(set) var legacyPetAnchorRemovalCount = 0

    init(
        enabled: Bool,
        windowAnchor: HaloWindowAnchor? = nil,
        petVisualCenterOffset: PetVisualCenterOffset = .zero
    ) {
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            windowAnchor: windowAnchor,
            petVisualCenterOffset: petVisualCenterOffset
        )
    }

    func load() -> WindowFollowingPreferenceSnapshot { snapshot }
    func removeLegacyPetAnchor() { legacyPetAnchorRemovalCount += 1 }

    func setFollowingEnabled(_ enabled: Bool) {
        enabledWrites.append(enabled)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: enabled,
            windowAnchor: snapshot.windowAnchor,
            petVisualCenterOffset: snapshot.petVisualCenterOffset
        )
    }

    func setWindowAnchor(_ anchor: HaloWindowAnchor?) {
        windowAnchorWrites.append(anchor)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: snapshot.followingEnabled,
            windowAnchor: anchor,
            petVisualCenterOffset: snapshot.petVisualCenterOffset
        )
    }

    func setPetVisualCenterOffset(_ offset: PetVisualCenterOffset) {
        petVisualCenterOffsetWrites.append(offset)
        snapshot = WindowFollowingPreferenceSnapshot(
            followingEnabled: snapshot.followingEnabled,
            windowAnchor: snapshot.windowAnchor,
            petVisualCenterOffset: offset
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
                self?.events.append(event)
            }
        }
    }

    var layouts: [PetAttachmentLayout] {
        events.compactMap { event in
            switch event {
            case let .activatePetAttachment(layout), let .placePetAttachment(layout):
                layout
            default:
                nil
            }
        }
    }

    var orientations: [PetRingOrientation] {
        events.compactMap { event in
            if case let .petRingOrientationChanged(orientation) = event {
                return orientation
            }
            return nil
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

final class WindowFollowingServiceTests: XCTestCase {
    @MainActor
    func testStartupNeverPromptsWithoutPermission() async {
        let permission = FakePermissionProvider(current: .notGranted, requested: .granted)
        let context = makeContext(permission: permission, enabled: true)

        context.service.start()

        XCTAssertEqual(context.service.state, .permissionRequired)
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertEqual(context.windowAccessor.resolveCount, 0)
        XCTAssertEqual(context.preferences.legacyPetAnchorRemovalCount, 1)
        await context.service.stop()
    }

    @MainActor
    func testExplicitEnableRequestsPermissionAndRequiresWindowCalibration() async {
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
    func testWindowCalibrationPersistsOnlyM4Anchor() async {
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
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertTrue(context.preferences.snapshot.windowAnchor?.isValid == true)
        XCTAssertEqual(context.preferences.legacyPetAnchorRemovalCount, 1)
        await context.service.stop()
    }

    @MainActor
    func testSavedWindowAnchorRemainsIntactDuringLegacyPetMigration() async {
        let anchor = windowAnchor()
        let context = makeContext(enabled: true, anchor: anchor)

        context.service.start()

        XCTAssertEqual(context.preferences.legacyPetAnchorRemovalCount, 1)
        XCTAssertEqual(context.preferences.snapshot.windowAnchor, anchor)
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        await context.service.stop()
    }

    @MainActor
    func testNoSavedPetAnchorAttachesAtExactCenter() async throws {
        let petFrame = CGRect(x: 500, y: 600, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())

        context.service.start()
        await waitForLayout(recorder)

        let layout = try XCTUnwrap(recorder.layouts.last)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.service.petPlacementStatus, .centered)
        XCTAssertEqual(layout.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(layout.panelFrame.midY, petFrame.midY)
        XCTAssertTrue(recorder.events.contains(.activatePetAttachment(layout)))
        XCTAssertFalse(recorder.events.contains(.targetSourceChanged(.pet)))
        XCTAssertFalse(recorder.events.contains(.stateChanged(.calibrationRequired)))
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testPetMovementAndResizePreserveExactCenterEquality() async throws {
        let initial = CGRect(x: 500, y: 300, width: 120, height: 110)
        let moved = CGRect(x: -420, y: -180, width: 150, height: 130)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: initial)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)

        let generation = try XCTUnwrap(context.petAccessor.snapshot?.generation)
        context.petAccessor.snapshot = PetTargetSnapshot(generation: generation, frame: moved)
        context.petAccessor.emit(.geometryChanged)
        for _ in 0 ..< 100 where recorder.layouts.last?.panelFrame.midX != moved.midX {
            await Task.yield()
        }

        let layout = try XCTUnwrap(recorder.layouts.last)
        XCTAssertEqual(layout.panelFrame.midX, moved.midX)
        XCTAssertEqual(layout.panelFrame.midY, moved.midY)
        XCTAssertEqual(context.windowAccessor.resolveCount, 0)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testPresentationSizeUpdatesCannotEnlargePetAttachment() async throws {
        let petFrame = CGRect(x: -900, y: 100, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)

        context.service.beginPresentationTransition()
        context.service.finishPresentationTransition(panelSize: CGSize(width: 360, height: 520))
        context.service.finishPresentationTransition(panelSize: CGSize(width: 9_000, height: 4_000))
        context.service.finishPresentationTransition(panelSize: .zero)
        for _ in 0 ..< 20 { await Task.yield() }

        let layout = try XCTUnwrap(recorder.layouts.last)
        XCTAssertEqual(layout.panelFrame.size, PetAttachmentLayoutPolicy.petAttachmentSize)
        XCTAssertEqual(layout.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(layout.panelFrame.midY, petFrame.midY)
        XCTAssertFalse(recorder.layouts.contains { $0.panelFrame.size == CGSize(width: 360, height: 520) })
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testActivityDialogCreationDoesNotGeneratePlacementChange() async {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)
        let count = recorder.layouts.count

        context.petAccessor.emit(.selectionChanged)
        for _ in 0 ..< 100 { await Task.yield() }

        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.petPlacementStatus, .centered)
        XCTAssertEqual(recorder.layouts.count, count)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testFineTunePersistsVisualCenterOffsetWithoutChangingTargetSelection() async throws {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)
        let initial = try XCTUnwrap(recorder.layouts.last)
        let petResolveCount = context.petAccessor.resolveCount
        context.service.beginPetCalibration(currentReferencePoint: initial.referencePoint)
        context.service.finishCalibration(
            currentReferencePoint: CGPoint(
                x: initial.referencePoint.x - 12,
                y: initial.referencePoint.y + 36
            )
        )
        for _ in 0 ..< 100 where recorder.layouts.last == initial { await Task.yield() }

        let layout = try XCTUnwrap(recorder.layouts.last)
        XCTAssertEqual(context.service.state, .following)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(layout.panelFrame.midX, petFrame.midX - 12)
        XCTAssertEqual(layout.panelFrame.midY, petFrame.midY + 36)
        XCTAssertEqual(
            context.preferences.petVisualCenterOffsetWrites,
            [PetVisualCenterOffset(horizontal: -12, vertical: 36)]
        )
        XCTAssertTrue(context.preferences.windowAnchorWrites.isEmpty)
        XCTAssertEqual(context.petAccessor.resolveCount, petResolveCount)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testDialogOrientationDebouncesAndAmbiguityRetainsPriorWithoutMovingPanel() async throws {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: petFrame,
                activityGeometryHint: .below
            )),
            enabled: true,
            orientationDebounce: .milliseconds(1)
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)
        for _ in 0 ..< 100 where recorder.orientations.last != .openingBottom {
            try await Task.sleep(for: .milliseconds(1))
        }
        let layoutCount = recorder.layouts.count
        XCTAssertEqual(recorder.orientations.last, .openingBottom)

        let generation = try XCTUnwrap(context.petAccessor.snapshot?.generation)
        context.petAccessor.snapshot = PetTargetSnapshot(
            generation: generation,
            frame: petFrame,
            activityGeometryHint: .ambiguous
        )
        context.petAccessor.emit(.activityGeometryChanged)
        try await Task.sleep(for: .milliseconds(5))
        XCTAssertEqual(recorder.orientations, [.openingBottom])

        context.petAccessor.snapshot = PetTargetSnapshot(
            generation: generation,
            frame: petFrame,
            activityGeometryHint: .above
        )
        context.petAccessor.emit(.activityGeometryChanged)
        for _ in 0 ..< 100 where recorder.orientations.last != .openingTop {
            try await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertEqual(recorder.orientations, [.openingBottom, .openingTop])
        XCTAssertEqual(recorder.layouts.count, layoutCount)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testStalePetGenerationCannotMovePanel() async throws {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)
        let initial = try XCTUnwrap(recorder.layouts.last)

        context.petAccessor.snapshot = PetTargetSnapshot(
            generation: -1,
            frame: CGRect(x: -900, y: -900, width: 200, height: 200)
        )
        context.petAccessor.emit(.geometryChanged, generation: -1)

        XCTAssertEqual(recorder.layouts.last, initial)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testTuckAwayAndWakeRestorePersistentVisualCenterOffset() async throws {
        let petFrame = CGRect(x: 500, y: 600, width: 120, height: 110)
        let offset = PetVisualCenterOffset(horizontal: -8, vertical: 32)
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(generation: 0, frame: petFrame)),
            enabled: true,
            anchor: windowAnchor(),
            petVisualCenterOffset: offset
        )
        let recorder = FollowingEventRecorder()
        recorder.start(context.service.events())
        context.service.start()
        await waitForLayout(recorder)

        context.petAccessor.result = .unavailable
        context.petAccessor.snapshot = nil
        context.petAccessor.emit(.targetInvalidated)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.service.petPlacementStatus, .unavailable)

        context.petAccessor.result = .selected(PetTargetSnapshot(generation: 0, frame: petFrame))
        context.windowAccessor.emit(.selectionChanged)
        for _ in 0 ..< 100 where context.service.targetSource != .pet {
            await Task.yield()
        }

        let recovered = try XCTUnwrap(recorder.layouts.last)
        XCTAssertEqual(context.service.targetSource, .pet)
        XCTAssertEqual(context.service.petPlacementStatus, .centered)
        XCTAssertEqual(recovered.panelFrame.midX, petFrame.midX - 8)
        XCTAssertEqual(recovered.panelFrame.midY, petFrame.midY + 32)
        XCTAssertEqual(context.preferences.snapshot.petVisualCenterOffset, offset)
        recorder.stop()
        await context.service.stop()
    }

    @MainActor
    func testExplicitWindowFallbackDoesNotChurnObserversOnRecoveryTick() async {
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true,
            anchor: windowAnchor()
        )
        context.service.start()
        context.service.useWindowFallback()
        let petResolveCount = context.petAccessor.resolveCount
        let windowResolveCount = context.windowAccessor.resolveCount

        context.service.recoverStateIfNeeded()

        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.petAccessor.resolveCount, petResolveCount)
        XCTAssertEqual(context.windowAccessor.resolveCount, windowResolveCount)
        await context.service.stop()
    }

    @MainActor
    func testPetAmbiguityUsesM4FallbackWithoutGuessing() async {
        let context = makeContext(
            petAccessResult: .ambiguous,
            enabled: true,
            anchor: windowAnchor()
        )

        context.service.start()

        XCTAssertEqual(context.service.petDiscoveryState, .ambiguous)
        XCTAssertEqual(context.service.targetSource, .codexWindowFallback)
        XCTAssertEqual(context.service.state, .following)
        await context.service.stop()
    }

    @MainActor
    func testBothTargetsUnavailableRemainFreeFloating() async {
        let context = makeContext(
            petAccessResult: .unavailable,
            accessResult: .unavailable,
            enabled: true
        )

        context.service.start()

        XCTAssertEqual(context.service.targetSource, .freeFloating)
        XCTAssertEqual(context.service.petPlacementStatus, .unavailable)
        await context.service.stop()
    }

    @MainActor
    func testObserverShutdownIsCleanAndIdempotent() async {
        let context = makeContext(
            petAccessResult: .selected(PetTargetSnapshot(
                generation: 0,
                frame: CGRect(x: 500, y: 300, width: 120, height: 110)
            )),
            enabled: true
        )
        context.service.start()
        let stopCountBeforeShutdown = context.petAccessor.stopCount

        await context.service.stop()
        await context.service.stop()

        XCTAssertEqual(context.petAccessor.stopCount, stopCountBeforeShutdown + 1)
        XCTAssertEqual(context.events.stopCount, 1)
    }

    @MainActor
    private func waitForLayout(_ recorder: FollowingEventRecorder) async {
        for _ in 0 ..< 100 where recorder.layouts.isEmpty {
            await Task.yield()
        }
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
        petVisualCenterOffset: PetVisualCenterOffset = .zero,
        orientationDebounce: Duration = .milliseconds(180)
    ) -> Context {
        let locator = FakeApplicationLocator(locatorSelection)
        let petAccessor = FakePetAccessor(result: petAccessResult)
        let windowAccessor = FakeWindowAccessor(result: accessResult)
        let events = FakeSystemEventSource()
        let preferences = FakeFollowingPreferences(
            enabled: enabled,
            windowAnchor: anchor,
            petVisualCenterOffset: petVisualCenterOffset
        )
        let service = WindowFollowingService(
            permissionProvider: permission,
            applicationLocator: locator,
            petAccessor: petAccessor,
            windowAccessor: windowAccessor,
            systemEvents: events,
            preferences: preferences,
            petOrientationDebounce: orientationDebounce
        )
        return Context(
            service: service,
            petAccessor: petAccessor,
            windowAccessor: windowAccessor,
            events: events,
            preferences: preferences
        )
    }

    private func windowAnchor() -> HaloWindowAnchor {
        HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
    }

    @MainActor
    private struct Context {
        let service: WindowFollowingService
        let petAccessor: FakePetAccessor
        let windowAccessor: FakeWindowAccessor
        let events: FakeSystemEventSource
        let preferences: FakeFollowingPreferences
    }
}
