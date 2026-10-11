import XCTest
@testable import PetHalo

@MainActor
final class PetPositioningServiceTests: XCTestCase {
    func testOnlyStartupAndExplicitRequestsCapture() async {
        var count = 0
        let service = PetPositioningService(capture: {
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
        let service = PetPositioningService(capture: {
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
        let service = PetPositioningService(capture: {
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
        XCTAssertEqual(events, [.petDiscoveryStateChanged(.searching)])
    }

    func testOverlappingRequestsAreCoalesced() async {
        var count = 0
        let service = PetPositioningService(capture: {
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
