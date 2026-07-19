import AppKit
import XCTest
@testable import PetHalo

final class HaloPanelTests: XCTestCase {
    @MainActor
    func testPanelUsesNonActivatingTransparentFloatingConfiguration() {
        let controller = makeController()
        guard let panel = controller.panel else {
            return XCTFail("Expected panel")
        }

        XCTAssertEqual(panel.styleMask, [.nonactivatingPanel])
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.styleMask.contains(.titled))
        XCTAssertFalse(panel.styleMask.contains(.resizable))
        controller.stop()
    }

    @MainActor
    func testShowHideAndModeChangesAreIdempotentAndContained() {
        let visibleFrame = NSRect(x: 100, y: 200, width: 800, height: 600)
        let controller = HaloPanelController(visibleFrameProvider: { visibleFrame })
        guard let panel = controller.panel else {
            return XCTFail("Expected panel")
        }

        XCTAssertTrue(visibleFrame.contains(panel.frame))
        XCTAssertEqual(panel.frame.size, HaloPanelController.compactSize)
        controller.show()
        controller.show()
        XCTAssertTrue(controller.isVisible)
        controller.setMode(.expanded)
        controller.setMode(.expanded)
        XCTAssertEqual(controller.mode, .expanded)
        XCTAssertEqual(panel.frame.size, HaloPanelController.expandedSize)
        XCTAssertTrue(visibleFrame.contains(panel.frame))
        XCTAssertTrue(panel.ignoresMouseEvents)
        controller.hide()
        controller.hide()
        XCTAssertFalse(controller.isVisible)
        controller.stop()
    }

    @MainActor
    func testStopClosesPanelAndReleasesOwnedContent() {
        weak var releasedPanel: HaloPanel?
        autoreleasepool {
            let controller = makeController()
            let panel = controller.panel
            releasedPanel = panel
            controller.show()

            controller.stop()
            controller.stop()

            XCTAssertNil(controller.panel)
            XCTAssertNil(panel?.contentView)
            XCTAssertFalse(panel?.isVisible == true)
        }
        XCTAssertNil(releasedPanel)
    }

    @MainActor
    private func makeController() -> HaloPanelController {
        HaloPanelController(
            visibleFrameProvider: {
                NSRect(x: 0, y: 0, width: 1_024, height: 768)
            }
        )
    }
}
