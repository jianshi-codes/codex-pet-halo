import CoreGraphics
import XCTest
@testable import PetHalo

final class PetTargetModelsTests: XCTestCase {
    func testSelectsSingleBalancedDialogAsPetCore() {
        XCTAssertEqual(
            PetWindowSelector.select(from: [candidate(1)]),
            .selected(
                memberIdentities: [1],
                frame: CGRect(x: 100, y: 200, width: 120, height: 110)
            )
        )
    }

    func testCollapsesOverlappingPetSurfacesWithoutArrayOrder() {
        let frame = CGRect(x: 100, y: 200, width: 120, height: 110)
        let first = candidate(1, frame: frame)
        let second = candidate(2, frame: frame)
        XCTAssertEqual(
            PetWindowSelector.select(from: [second, first]),
            .selected(memberIdentities: [1, 2], frame: frame)
        )
    }

    func testSubpointOverlapUsesDeterministicAveragedFrame() {
        let firstFrame = CGRect(x: 100, y: 200, width: 120, height: 110)
        let secondFrame = CGRect(x: 100.2, y: 199.8, width: 120.2, height: 109.8)
        let expected = CGRect(x: 100.1, y: 199.9, width: 120.1, height: 109.9)
        let forward = PetWindowSelector.select(from: [
            candidate(1, frame: firstFrame),
            candidate(2, frame: secondFrame),
        ])
        let reversed = PetWindowSelector.select(from: [
            candidate(2, frame: secondFrame),
            candidate(1, frame: firstFrame),
        ])

        XCTAssertEqual(forward, .selected(memberIdentities: [1, 2], frame: expected))
        XCTAssertEqual(reversed, forward)
    }

    func testExcludesActivityWindowAndSystemDialogButtons() {
        let pet = candidate(1)
        let activity = candidate(
            2,
            subrole: "AXDialog",
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )
        let button = candidate(
            3,
            subrole: "AXSystemDialog",
            frame: CGRect(x: 230, y: 170, width: 30, height: 30)
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [activity, button, pet]),
            .selected(memberIdentities: [1], frame: pet.frame)
        )
    }

    func testActivityWindowMayAppearAboveOrBelowWithoutChangingSelection() {
        let pet = candidate(1)
        let above = candidate(
            2,
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )
        let below = candidate(
            3,
            frame: CGRect(x: 40, y: 360, width: 360, height: 70)
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [pet, above]),
            .selected(memberIdentities: [1], frame: pet.frame)
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [below, pet]),
            .selected(memberIdentities: [1], frame: pet.frame)
        )
    }

    func testMultipleBalancedDialogFramesAreAmbiguous() {
        XCTAssertEqual(
            PetWindowSelector.select(from: [
                candidate(1),
                candidate(2, frame: CGRect(x: 500, y: 200, width: 120, height: 110)),
            ]),
            .ambiguous
        )
    }

    func testSimilarlySizedUnrelatedDialogMakesSelectionAmbiguous() {
        XCTAssertEqual(
            PetWindowSelector.select(from: [
                candidate(1),
                candidate(2, frame: CGRect(x: 360, y: 200, width: 118, height: 112)),
                candidate(3, role: "AXGroup"),
            ]),
            .ambiguous
        )
    }

    func testHiddenMinimizedWideAndInvalidCandidatesAreUnavailable() {
        XCTAssertEqual(
            PetWindowSelector.select(from: [
                candidate(1, hidden: true),
                candidate(2, minimized: true),
                candidate(3, frame: CGRect(x: 0, y: 0, width: 360, height: 70)),
                candidate(4, frame: .zero),
            ]),
            .unavailable
        )
    }

    func testPetAnchorCalibrationAndMovementAreIndependentFromWindowGeometry() throws {
        let anchor = try XCTUnwrap(PetAnchorGeometry.calibrate(
            referencePoint: CGPoint(x: 250, y: 350),
            petFrame: CGRect(x: 100, y: 200, width: 100, height: 100)
        ))
        XCTAssertEqual(anchor.normalizedPetPoint, UnitPointValue(x: 1, y: 1))
        XCTAssertEqual(anchor.pointOffset, PointOffsetValue(width: 50, height: 50))
        XCTAssertEqual(
            PetAnchorGeometry.referencePoint(
                anchor: anchor,
                petFrame: CGRect(x: -400, y: -200, width: 140, height: 120)
            ),
            CGPoint(x: -210, y: -30)
        )
    }

    func testPetAnchorRejectsUnsupportedNonFiniteAndUnreasonableValues() {
        let validPoint = UnitPointValue(x: 0.5, y: 0.5)
        XCTAssertFalse(PetRelativeAnchor(
            version: 0,
            normalizedPetPoint: validPoint,
            pointOffset: PointOffsetValue(width: 0, height: 0)
        ).isValid)
        XCTAssertFalse(PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: .infinity, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        ).isValid)
        XCTAssertFalse(PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: validPoint,
            pointOffset: PointOffsetValue(width: 20_000, height: 0)
        ).isValid)
    }

    func testTargetAndDiscoveryStatusTextExposeNoRawAccessibilityData() {
        XCTAssertEqual(HaloFollowingTargetSource.pet.statusText, "Target: Pet")
        XCTAssertEqual(
            HaloFollowingTargetSource.codexWindowFallback.statusText,
            "Target: Codex Window"
        )
        XCTAssertEqual(HaloFollowingTargetSource.freeFloating.statusText, "Target: Free-floating")
        XCTAssertEqual(PetTargetDiscoveryState.searching.statusText, "Pet: Searching")
        XCTAssertEqual(PetTargetDiscoveryState.unavailable.statusText, "Pet: Not Found")
        XCTAssertEqual(PetTargetDiscoveryState.ambiguous.statusText, "Pet: Ambiguous")
    }

    private func candidate(
        _ identity: Int,
        minimized: Bool = false,
        hidden: Bool = false,
        role: String? = "AXWindow",
        subrole: String? = "AXDialog",
        frame: CGRect = CGRect(x: 100, y: 200, width: 120, height: 110)
    ) -> PetWindowCandidate {
        PetWindowCandidate(
            identity: identity,
            frame: frame,
            isMinimized: minimized,
            isHidden: hidden,
            role: role,
            subrole: subrole
        )
    }
}
