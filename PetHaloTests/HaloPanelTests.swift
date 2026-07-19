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
        let controller = HaloPanelController(
            model: Self.maximumContentModel,
            visibleFrameProvider: { visibleFrame }
        )
        guard let panel = controller.panel else {
            return XCTFail("Expected panel")
        }

        XCTAssertTrue(visibleFrame.contains(panel.frame))
        XCTAssertEqual(panel.frame.size, HaloPanelController.compactSize)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        controller.show()
        controller.show()
        XCTAssertTrue(controller.isVisible)
        controller.setMode(.expanded)
        controller.setMode(.expanded)
        XCTAssertEqual(controller.mode, .expanded)
        XCTAssertEqual(panel.frame.size, HaloPanelController.expandedSize)
        XCTAssertTrue(visibleFrame.contains(panel.frame))
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        controller.hide()
        controller.hide()
        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(panel.ignoresMouseEvents)
        controller.show()
        XCTAssertTrue(controller.isVisible)
        XCTAssertFalse(panel.ignoresMouseEvents)
        controller.setMode(.compact)
        controller.setMode(.compact)
        XCTAssertEqual(controller.mode, .compact)
        XCTAssertEqual(panel.frame.size, HaloPanelController.compactSize)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        controller.stop()
    }

    @MainActor
    func testExpandedPanelLaysOutMaximumSupportedContentFixture() {
        let model = Self.maximumContentModel
        guard case let .current(usage) = model.accountUsage else {
            return XCTFail("Expected current Account Usage")
        }
        XCTAssertEqual(usage.summaryRows.count, 5)
        XCTAssertEqual(usage.dailyRows.count, 7)

        let controller = HaloPanelController(
            model: model,
            visibleFrameProvider: {
                NSRect(x: 0, y: 0, width: 1_024, height: 768)
            }
        )
        controller.setMode(.expanded)
        guard let panel = controller.panel, let contentView = panel.contentView else {
            return XCTFail("Expected expanded hosted content")
        }
        contentView.layoutSubtreeIfNeeded()

        XCTAssertEqual(panel.frame.size, HaloPanelController.expandedSize)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
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

    private static let maximumContentModel = HaloPresentationModel(
        connectionState: .connected,
        weekly: .current(
            QuotaPresentation(
                remainingPercent: 73.4,
                displayedPercent: 73,
                resetText: "Resets in 5 days",
                resetAccessibilityValue: "Jul 25, 2026 at 8:00 AM"
            )
        ),
        fiveHour: .current(
            QuotaPresentation(
                remainingPercent: 42.1,
                displayedPercent: 42,
                resetText: "Resets in 2 hours",
                resetAccessibilityValue: "Jul 20, 2026 at 8:00 AM"
            )
        ),
        accountUsage: .current(
            AccountUsagePresentation(
                summaryRows: [
                    AccountUsageRowPresentation(label: "Lifetime tokens", value: "1,234,567"),
                    AccountUsageRowPresentation(label: "Peak daily tokens", value: "234,567"),
                    AccountUsageRowPresentation(label: "Longest turn", value: "1 hr 23 min"),
                    AccountUsageRowPresentation(label: "Current streak (days)", value: "12"),
                    AccountUsageRowPresentation(label: "Longest streak (days)", value: "34"),
                ],
                dailyRows: (0 ..< 7).map { day in
                    DailyUsagePresentation(
                        date: Date(timeIntervalSince1970: TimeInterval(1_750_000_000 - day * 86_400)),
                        dateText: "Day \(day + 1)",
                        tokenText: "\((day + 1) * 12_345)"
                    )
                }
            )
        ),
        aggregateFreshness: .current
    )
}
