import CoreGraphics
import XCTest
@testable import PetHalo

final class WindowFollowingModelsTests: XCTestCase {
    func testProcessSelectionUsesOnlyExactBundleIdentifier() {
        XCTAssertEqual(
            CodexApplicationSelector.select(from: [
                candidate(1, "com.example.CodexHelper"),
                candidate(2, "com.openai.codex.preview"),
            ]),
            .unavailable
        )
        XCTAssertEqual(
            CodexApplicationSelector.select(from: [
                candidate(1, "com.example.CodexHelper"),
                candidate(2, CodexApplicationSelector.bundleIdentifier),
            ]),
            .selected(processIdentifier: 2)
        )
    }

    func testProcessSelectionUsesSoleActiveExactCandidateAndRejectsAmbiguity() {
        XCTAssertEqual(
            CodexApplicationSelector.select(from: [
                candidate(1, CodexApplicationSelector.bundleIdentifier),
                candidate(2, CodexApplicationSelector.bundleIdentifier, active: true),
            ]),
            .selected(processIdentifier: 2)
        )
        XCTAssertEqual(
            CodexApplicationSelector.select(from: [
                candidate(1, CodexApplicationSelector.bundleIdentifier),
                candidate(2, CodexApplicationSelector.bundleIdentifier),
            ]),
            .ambiguous
        )
    }

    func testWindowSelectionOrderIsFocusedThenMainThenOnlyEligible() {
        let ordinary = window(1)
        let main = window(2, main: true)
        let focused = window(3, focused: true)
        XCTAssertEqual(
            CodexWindowSelector.select(from: [ordinary, main, focused]),
            .selected(identity: 3)
        )
        XCTAssertEqual(
            CodexWindowSelector.select(from: [ordinary, main]),
            .selected(identity: 2)
        )
        XCTAssertEqual(
            CodexWindowSelector.select(from: [ordinary]),
            .selected(identity: 1)
        )
    }

    func testWindowSelectionRejectsMinimizedTransientZeroSizedAndAmbiguousWindows() {
        XCTAssertEqual(
            CodexWindowSelector.select(from: [
                window(1, minimized: true),
                window(2, role: "AXSheet"),
                window(3, subrole: "AXDialog"),
                window(4, frame: .zero),
            ]),
            .unavailable
        )
        XCTAssertEqual(
            CodexWindowSelector.select(from: [window(1), window(2)]),
            .ambiguous
        )
    }

    func testCoordinateConversionPreservesLeftAndBelowNegativeOrigins() {
        let converter = AXCoordinateConverter(
            primaryDisplayFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )
        XCTAssertEqual(
            converter.appKitFrame(
                fromAccessibilityFrame: CGRect(x: -1_200, y: 100, width: 800, height: 600)
            ),
            CGRect(x: -1_200, y: 380, width: 800, height: 600)
        )
        XCTAssertEqual(
            converter.appKitFrame(
                fromAccessibilityFrame: CGRect(x: 100, y: 1_200, width: 800, height: 600)
            ),
            CGRect(x: 100, y: -720, width: 800, height: 600)
        )
    }

    func testCoordinateConversionHandlesMixedSizesAndBoundaryCrossingWithoutScaling() {
        let converter = AXCoordinateConverter(
            primaryDisplayFrame: CGRect(x: 0, y: 0, width: 2_560, height: 1_440)
        )
        XCTAssertEqual(
            converter.appKitFrame(
                fromAccessibilityFrame: CGRect(x: -100, y: 200, width: 600, height: 900)
            ),
            CGRect(x: -100, y: 340, width: 600, height: 900)
        )
    }

    func testCalibrationProjectsOutsideReferenceAndAppliesAfterMoveAndResize() {
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        let reference = CGPoint(x: 940, y: 700)
        let anchor = HaloAnchorGeometry.calibrate(
            referencePoint: reference,
            windowFrame: window
        )
        XCTAssertEqual(anchor?.normalizedWindowPoint, UnitPointValue(x: 1, y: 5.0 / 6.0))
        XCTAssertEqual(anchor?.pointOffset, PointOffsetValue(width: 40, height: 0))
        XCTAssertEqual(
            HaloAnchorGeometry.referencePoint(
                anchor: anchor!,
                windowFrame: CGRect(x: 200, y: 300, width: 1_000, height: 300)
            ),
            CGPoint(x: 1_240, y: 550)
        )
    }

    func testAnchorValidationRejectsUnsupportedNonFiniteAndUnreasonableValues() throws {
        let valid = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 20, height: -20)
        )
        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(
            HaloWindowAnchor(
                version: 0,
                normalizedWindowPoint: valid.normalizedWindowPoint,
                pointOffset: valid.pointOffset
            ).isValid
        )
        XCTAssertFalse(
            HaloWindowAnchor(
                version: 1,
                normalizedWindowPoint: UnitPointValue(x: .nan, y: 0.5),
                pointOffset: valid.pointOffset
            ).isValid
        )
        XCTAssertFalse(
            HaloWindowAnchor(
                version: 1,
                normalizedWindowPoint: valid.normalizedWindowPoint,
                pointOffset: PointOffsetValue(width: 20_000, height: 0)
            ).isValid
        )
    }

    func testMultiDisplayContainmentUsesAnchorScreenVisibleFrame() {
        let screens = [
            ScreenGeometry(
                frame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
                visibleFrame: CGRect(x: 0, y: 24, width: 1_920, height: 1_020)
            ),
            ScreenGeometry(
                frame: CGRect(x: -1_280, y: 0, width: 1_280, height: 1_024),
                visibleFrame: CGRect(x: -1_280, y: 0, width: 1_280, height: 1_000)
            ),
            ScreenGeometry(
                frame: CGRect(x: 0, y: -900, width: 1_600, height: 900),
                visibleFrame: CGRect(x: 0, y: -860, width: 1_600, height: 860)
            ),
        ]
        XCTAssertEqual(
            HaloPlacementGeometry.containedFrame(
                referencePoint: CGPoint(x: -10, y: 1_010),
                size: CGSize(width: 360, height: 520),
                screens: screens
            ),
            CGRect(x: -370, y: 480, width: 360, height: 520)
        )
        XCTAssertEqual(
            HaloPlacementGeometry.containedFrame(
                referencePoint: CGPoint(x: 100, y: -880),
                size: CGSize(width: 176, height: 176),
                screens: screens
            )?.minY,
            -860
        )
    }

    func testScreenRemovalChoosesNearestRemainingVisibleFrameAndOversizedHaloShrinks() {
        let onlyScreen = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            visibleFrame: CGRect(x: 0, y: 20, width: 800, height: 560)
        )
        let frame = HaloPlacementGeometry.containedFrame(
            referencePoint: CGPoint(x: -2_000, y: 2_000),
            size: CGSize(width: 1_000, height: 900),
            screens: [onlyScreen]
        )
        XCTAssertEqual(frame, onlyScreen.visibleFrame)
    }

    private func candidate(
        _ pid: Int32,
        _ bundleIdentifier: String,
        active: Bool = false
    ) -> CodexApplicationCandidate {
        CodexApplicationCandidate(
            processIdentifier: pid,
            bundleIdentifier: bundleIdentifier,
            isActive: active
        )
    }

    private func window(
        _ identity: Int,
        focused: Bool = false,
        main: Bool = false,
        minimized: Bool = false,
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow",
        frame: CGRect = CGRect(x: 10, y: 20, width: 800, height: 600)
    ) -> CodexWindowCandidate {
        CodexWindowCandidate(
            identity: identity,
            frame: frame,
            isFocused: focused,
            isMain: main,
            isMinimized: minimized,
            isVisible: true,
            role: role,
            subrole: subrole
        )
    }
}
