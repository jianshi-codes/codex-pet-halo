import XCTest
@testable import PetHalo

@MainActor
private final class PositioningApplicationLocator: CodexApplicationLocating {
    var selection: CodexApplicationSelection = .selected(processIdentifier: 123)
    func locate() -> CodexApplicationSelection { selection }
}

@MainActor
private final class PositioningSystemEvents: WindowFollowingSystemEventSourcing {
    let pair = AsyncStream.makeStream(of: WindowFollowingSystemEvent.self)
    private(set) var stopCount = 0
    func events() -> AsyncStream<WindowFollowingSystemEvent> { pair.stream }
    func start() {}
    func stop() { stopCount += 1 }
    func changed() { pair.continuation.yield(.codexEnvironmentChanged) }
}

@MainActor
private final class PositioningDelay {
    var pending: CheckedContinuation<Void, Never>?
    func wait() async { await withCheckedContinuation { pending = $0 } }
    func advance() { let continuation = pending; pending = nil; continuation?.resume() }
}

@MainActor
final class PetPositioningServiceTests: XCTestCase {
    private func makeService(
        capture: @escaping @MainActor (Int32) async -> CGRect?
    ) -> PetPositioningService {
        PetPositioningService(
            applicationLocator: PositioningApplicationLocator(),
            systemEvents: PositioningSystemEvents(),
            capture: capture
        )
    }

    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }

    func testNoCaptureWithoutCodexAndLaunchPositionsOnce() async {
        let locator = PositioningApplicationLocator()
        locator.selection = .unavailable
        let events = PositioningSystemEvents()
        var captures = 0
        let service = PetPositioningService(applicationLocator: locator, systemEvents: events, capture: { _ in
            captures += 1
            return CGRect(x: 100, y: 100, width: 80, height: 120)
        })
        service.start()
        await settle()
        XCTAssertEqual(captures, 0)
        locator.selection = .selected(processIdentifier: 456)
        events.changed()
        await settle()
        XCTAssertEqual(captures, 1)
        events.changed() // Activation of the same process must not trigger capture.
        await settle()
        XCTAssertEqual(captures, 1)
        await service.stop()
        XCTAssertEqual(events.stopCount, 1)
    }

    func testCodexQuitHidesHaloAndDiscardsLateImage() async {
        let locator = PositioningApplicationLocator()
        let events = PositioningSystemEvents()
        let entered = expectation(description: "capture started")
        var pending: CheckedContinuation<CGRect?, Never>?
        let service = PetPositioningService(applicationLocator: locator, systemEvents: events, capture: { _ in
            await withCheckedContinuation { pending = $0; entered.fulfill() }
        })
        var output: [HaloWindowFollowingEvent] = []
        let reader = Task { for await event in service.events() { output.append(event) } }
        service.start()
        await fulfillment(of: [entered], timeout: 2)
        locator.selection = .unavailable
        events.changed()
        await settle()
        XCTAssertEqual(output.last, .petDiscoveryStateChanged(.unavailable))
        XCTAssertTrue(output.contains(.targetSourceChanged(.freeFloating)))
        pending?.resume(returning: CGRect(x: 100, y: 100, width: 80, height: 120))
        await settle()
        XCTAssertFalse(output.contains { if case .activatePetAttachment = $0 { true } else { false } })
        service.enable()
        await settle()
        await service.stop()
        await reader.value
    }

    func testFollowingIsOptInAndSwitchOffStopsCapturing() async {
        let locator = PositioningApplicationLocator()
        let events = PositioningSystemEvents()
        let delay = PositioningDelay()
        var captures = 0
        let service = PetPositioningService(
            applicationLocator: locator, systemEvents: events,
            followingDelay: { await delay.wait() }
        ) { _ in
            captures += 1
            return CGRect(x: captures * 10, y: 100, width: 80, height: 120)
        }
        service.start()
        await settle()
        XCTAssertEqual(captures, 1)
        XCTAssertNil(delay.pending) // No scheduled work in the default fixed mode.
        service.setContinuousFollowingEnabled(true)
        await settle()
        XCTAssertEqual(captures, 2)
        XCTAssertNotNil(delay.pending)
        delay.advance()
        await settle()
        XCTAssertEqual(captures, 3)
        service.setContinuousFollowingEnabled(false)
        delay.advance() // Even a late timer must not capture after switch-off.
        await settle()
        XCTAssertEqual(captures, 3)
        XCTAssertNil(service.samplePetAttachmentLayout())
        await service.stop()
    }

    func testQuitWhileFollowingStopsTimerAndRelaunchRepositions() async {
        let locator = PositioningApplicationLocator()
        let events = PositioningSystemEvents()
        let delay = PositioningDelay()
        var capturedPIDs: [Int32] = []
        let service = PetPositioningService(
            applicationLocator: locator, systemEvents: events,
            followingDelay: { await delay.wait() }
        ) { pid in
            capturedPIDs.append(pid)
            return CGRect(x: 100, y: 100, width: 80, height: 120)
        }
        service.start()
        await settle()
        service.setContinuousFollowingEnabled(true)
        await settle()
        locator.selection = .unavailable
        events.changed()
        await settle()
        delay.advance()
        await settle()
        XCTAssertEqual(capturedPIDs, [123, 123])
        locator.selection = .selected(processIdentifier: 456)
        events.changed()
        await settle()
        XCTAssertEqual(capturedPIDs, [123, 123, 456])
        await service.stop()
        delay.advance()
        await settle()
        XCTAssertEqual(capturedPIDs.count, 3)
    }

    func testOnlyStartupAndExplicitRequestsCapture() async {
        var count = 0
        let service = makeService(capture: { _ in
            count += 1
            return CGRect(x: 100, y: 100, width: 80, height: 120)
        })
        service.start()
        service.start()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(count, 1)
        for _ in 0..<100 { XCTAssertNil(service.samplePetAttachmentLayout()) }
        XCTAssertEqual(count, 1)
        service.enable()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(count, 2)
        await service.stop()
        service.enable()
        XCTAssertEqual(count, 2)
    }

    func testFailedRelocationPreservesLastLayout() async {
        var count = 0
        let service = makeService(capture: { _ in
            count += 1
            return count == 1 ? CGRect(x: 100, y: 100, width: 80, height: 120) : nil
        })
        let positioned = expectation(description: "initial position")
        let unavailable = expectation(description: "failed relocation")
        var layouts: [PetAttachmentLayout] = []
        let reader = Task {
            for await event in service.events() {
                switch event {
                case let .activatePetAttachment(layout):
                    layouts.append(layout)
                    positioned.fulfill()
                case .petDiscoveryStateChanged(.unavailable): unavailable.fulfill()
                case let .placePetAttachment(layout, _): layouts.append(layout)
                default: break
                }
            }
        }
        service.start()
        await fulfillment(of: [positioned], timeout: 2)
        service.enable()
        await fulfillment(of: [unavailable], timeout: 2)
        service.finishPresentationTransition(panelSize: .zero)
        await service.stop()
        await reader.value
        XCTAssertEqual(count, 2)
        XCTAssertEqual(layouts.count, 2)
        XCTAssertEqual(layouts.first, layouts.last)
    }

    func testShutdownDiscardsLateCaptureResult() async {
        let entered = expectation(description: "capture entered")
        var pending: CheckedContinuation<CGRect?, Never>?
        let service = makeService(capture: { _ in
            await withCheckedContinuation { continuation in
                pending = continuation
                entered.fulfill()
            }
        })
        let reader = Task { () -> [HaloWindowFollowingEvent] in
            var events: [HaloWindowFollowingEvent] = []
            for await event in service.events() { events.append(event) }
            return events
        }
        service.start()
        await fulfillment(of: [entered], timeout: 2)
        await service.stop()
        pending?.resume(returning: CGRect(x: 100, y: 100, width: 80, height: 120))
        let events = await reader.value
        XCTAssertTrue(events.contains(.petDiscoveryStateChanged(.searching)))
        XCTAssertFalse(events.contains { if case .activatePetAttachment = $0 { true } else { false } })
    }

    func testOverlappingRequestsAreCoalesced() async {
        var count = 0
        let service = makeService(capture: { _ in
            count += 1
            try? await Task.sleep(for: .milliseconds(20))
            return nil
        })
        service.start()
        service.enable()
        service.enable()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(count, 1)
        await service.stop()
    }
}
