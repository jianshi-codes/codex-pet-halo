import CoreGraphics
import XCTest
@testable import PetHalo

final class PetTargetModelsTests: XCTestCase {
    func testAutomaticAttachmentKeepsPanelAndPetCentersAligned() throws {
        let rawPetFrame = CGRect(x: 300, y: 200, width: 400, height: 400)
        let aboveLayout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: rawPetFrame,
            panelSize: CGSize(width: 176, height: 176),
            side: .above
        ))
        let belowLayout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: rawPetFrame,
            panelSize: CGSize(width: 176, height: 176),
            side: .below
        ))
        XCTAssertEqual(aboveLayout.panelFrame, CGRect(x: 412, y: 312, width: 176, height: 176))
        XCTAssertEqual(aboveLayout.panelFrame.midX, rawPetFrame.midX)
        XCTAssertEqual(aboveLayout.panelFrame.midY, rawPetFrame.midY)
        XCTAssertEqual(belowLayout.panelFrame, aboveLayout.panelFrame)
        XCTAssertEqual(aboveLayout.side, .above)
        XCTAssertEqual(belowLayout.side, .below)
    }

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

    func testActivitySelectorReturnsOnlyUniqueWideNearbyDialog() {
        let pet = candidate(1)
        let activity = candidate(
            2,
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )
        XCTAssertEqual(
            PetActivityWindowSelector.select(
                from: [pet, activity],
                excluding: [1],
                near: pet.frame
            ),
            activity
        )
        XCTAssertNil(PetActivityWindowSelector.select(
            from: [
                pet,
                activity,
                candidate(3, frame: CGRect(x: 30, y: 340, width: 340, height: 80)),
            ],
            excluding: [1],
            near: pet.frame
        ))

        let paddedPet = candidate(
            4,
            frame: CGRect(x: 300, y: 200, width: 400, height: 400)
        )
        let activityWithinPaddedSurface = candidate(
            5,
            frame: CGRect(x: 380, y: 420, width: 240, height: 48)
        )
        XCTAssertEqual(
            PetActivityWindowSelector.select(
                from: [paddedPet, activityWithinPaddedSurface],
                excluding: [4],
                near: paddedPet.frame
            ),
            activityWithinPaddedSurface
        )
        XCTAssertNil(PetActivityWindowSelector.select(
            from: [
                paddedPet,
                activityWithinPaddedSurface,
                candidate(6, frame: CGRect(x: 400, y: 120, width: 220, height: 44)),
            ],
            excluding: [4],
            near: paddedPet.frame
        ))
    }

    func testAdaptivePreferenceUsesActivityComplementAndScreenHalf() {
        let visible = CGRect(x: 0, y: 0, width: 1_200, height: 900)
        let pet = CGRect(x: 500, y: 400, width: 120, height: 110)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: pet,
            activityFrame: CGRect(x: 400, y: 250, width: 360, height: 70),
            visibleFrame: visible,
            currentSide: nil
        ), .above)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: pet,
            activityFrame: CGRect(x: 400, y: 600, width: 360, height: 70),
            visibleFrame: visible,
            currentSide: nil
        ), .below)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: CGRect(x: 500, y: 700, width: 120, height: 110),
            activityFrame: nil,
            visibleFrame: visible,
            currentSide: nil
        ), .above)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: CGRect(x: 500, y: 100, width: 120, height: 110),
            activityFrame: nil,
            visibleFrame: visible,
            currentSide: nil
        ), .below)
    }

    func testScreenHalfHysteresisIgnoresMidpointJitter() {
        let visible = CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: CGRect(x: 400, y: 440, width: 100, height: 100),
            activityFrame: nil,
            visibleFrame: visible,
            currentSide: .above
        ), .above)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: CGRect(x: 400, y: 360, width: 100, height: 100),
            activityFrame: nil,
            visibleFrame: visible,
            currentSide: .above
        ), .above)
        XCTAssertEqual(PetAttachmentLayoutPolicy.preferredSide(
            petFrame: CGRect(x: 400, y: 280, width: 100, height: 100),
            activityFrame: nil,
            visibleFrame: visible,
            currentSide: .above
        ), .below)
    }

    func testCenteredLayoutDoesNotShiftAtDisplayEdges() throws {
        let pet = CGRect(x: -40, y: -30, width: 100, height: 70)
        let layout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: pet,
            panelSize: CGSize(width: 176, height: 176),
            side: .above
        ))
        XCTAssertEqual(layout.panelFrame.midX, pet.midX)
        XCTAssertEqual(layout.panelFrame.midY, pet.midY)
        XCTAssertEqual(layout.referencePoint, HaloPlacementGeometry.referencePoint(for: layout.panelFrame))
    }

    func testLayoutSupportsNegativeCoordinateDisplay() throws {
        let pet = CGRect(x: -1_100, y: -450, width: 120, height: 110)
        let layout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: pet,
            panelSize: CGSize(width: 176, height: 176),
            side: .below
        ))
        XCTAssertEqual(layout.side, .below)
        XCTAssertEqual(layout.panelFrame.midX, pet.midX)
        XCTAssertEqual(layout.panelFrame.midY, pet.midY)
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
        XCTAssertEqual(
            PetPlacementStatus.automatic(.above).statusText,
            "Pet placement: Automatic Centered"
        )
        XCTAssertEqual(PetPlacementStatus.manual.statusText, "Pet placement: Fine-tuned")
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
