import XCTest
@testable import PetHalo

final class ApplicationCoordinatorTests: XCTestCase {
    @MainActor
    func testLifecycleTransitionsAndTerminatesOnce() {
        var terminationCount = 0
        let coordinator = ApplicationCoordinator {
            terminationCount += 1
        }

        XCTAssertEqual(coordinator.state, .initialized)

        coordinator.start()
        coordinator.start()
        XCTAssertEqual(coordinator.state, .running)

        coordinator.requestTermination()
        coordinator.requestTermination()
        XCTAssertEqual(coordinator.state, .terminationRequested)
        XCTAssertEqual(terminationCount, 1)

        coordinator.didTerminate()
        coordinator.didTerminate()
        XCTAssertEqual(coordinator.state, .stopped)
    }

    @MainActor
    func testTerminationBeforeStartIsIgnored() {
        var terminationCount = 0
        let coordinator = ApplicationCoordinator {
            terminationCount += 1
        }

        coordinator.requestTermination()

        XCTAssertEqual(coordinator.state, .initialized)
        XCTAssertEqual(terminationCount, 0)
    }
}
