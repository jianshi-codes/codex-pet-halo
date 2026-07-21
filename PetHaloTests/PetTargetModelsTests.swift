import CoreGraphics
import XCTest
@testable import PetHalo

final class PetTargetModelsTests: XCTestCase {
    func testCenteredLayoutKeepsExactPetMidpointWithoutScreenGeometry() throws {
        let petFrame = CGRect(x: 300, y: 200, width: 400, height: 400)
        let layout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petFrame,
            panelSize: CGSize(width: 176, height: 176)
        ))

        XCTAssertEqual(layout.panelFrame, CGRect(x: 412, y: 312, width: 176, height: 176))
        XCTAssertEqual(layout.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(layout.panelFrame.midY, petFrame.midY)
        XCTAssertEqual(
            layout.referencePoint,
            HaloPlacementGeometry.referencePoint(for: layout.panelFrame)
        )
    }

    func testPanelSizeChangesRecenterAroundSamePetMidpoint() throws {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let compact = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petFrame,
            panelSize: CGSize(width: 176, height: 176)
        ))
        let expanded = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petFrame,
            panelSize: CGSize(width: 360, height: 520)
        ))

        XCTAssertEqual(compact.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(compact.panelFrame.midY, petFrame.midY)
        XCTAssertEqual(expanded.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(expanded.panelFrame.midY, petFrame.midY)
    }

    func testVisualCenterOffsetAppliesEquallyAndRemainsConstantDuringPetMovement() throws {
        let offset = PetVisualCenterOffset(horizontal: -12, vertical: 36)
        let firstPet = CGRect(x: 100, y: 200, width: 120, height: 110)
        let movedPet = CGRect(x: 640, y: -300, width: 120, height: 110)
        let first = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: firstPet,
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
            visualCenterOffset: offset
        ))
        let moved = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: movedPet,
            panelSize: PetAttachmentLayoutPolicy.petAttachmentSize,
            visualCenterOffset: offset
        ))

        XCTAssertEqual(first.panelFrame.midX - firstPet.midX, -12)
        XCTAssertEqual(first.panelFrame.midY - firstPet.midY, 36)
        XCTAssertEqual(moved.panelFrame.midX - movedPet.midX, -12)
        XCTAssertEqual(moved.panelFrame.midY - movedPet.midY, 36)
        XCTAssertEqual(moved.panelFrame.origin.x - first.panelFrame.origin.x, 540)
        XCTAssertEqual(moved.panelFrame.origin.y - first.panelFrame.origin.y, -500)
    }

    func testFineTuneReferenceProducesOnlyAConstantVisualCenterOffset() throws {
        let petFrame = CGRect(x: 500, y: 300, width: 120, height: 110)
        let panelSize = PetAttachmentLayoutPolicy.petAttachmentSize
        let reference = CGPoint(
            x: petFrame.midX + 18 + panelSize.width / 2,
            y: petFrame.midY - 24 + panelSize.height / 2
        )

        XCTAssertEqual(
            PetAttachmentLayoutPolicy.visualCenterOffset(
                panelReferencePoint: reference,
                petFrame: petFrame,
                panelSize: panelSize
            ),
            PetVisualCenterOffset(horizontal: 18, vertical: -24)
        )
    }

    func testVisualCenterOffsetAcceptsObservedCalibrationAndRemainsBounded() {
        XCTAssertTrue(PetVisualCenterOffset(horizontal: 18, vertical: -132).isValid)
        XCTAssertTrue(PetVisualCenterOffset(horizontal: 252, vertical: -252).isValid)
        XCTAssertFalse(PetVisualCenterOffset(horizontal: 253, vertical: 0).isValid)
        XCTAssertFalse(PetVisualCenterOffset(horizontal: 0, vertical: -.infinity).isValid)
    }

    func testCenteredLayoutSupportsNegativeDisplayCoordinates() throws {
        let petFrame = CGRect(x: -1_100, y: -450, width: 120, height: 110)
        let layout = try XCTUnwrap(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: petFrame,
            panelSize: CGSize(width: 176, height: 176)
        ))

        XCTAssertEqual(layout.panelFrame.midX, petFrame.midX)
        XCTAssertEqual(layout.panelFrame.midY, petFrame.midY)
    }

    func testCenteredLayoutRejectsInvalidGeometry() {
        XCTAssertNil(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: .zero,
            panelSize: CGSize(width: 176, height: 176)
        ))
        XCTAssertNil(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: CGRect(x: CGFloat.infinity, y: 0, width: 100, height: 100),
            panelSize: CGSize(width: 176, height: 176)
        ))
        XCTAssertNil(PetAttachmentLayoutPolicy.centeredLayout(
            petFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            panelSize: .zero
        ))
    }

    func testPrefersStableSystemDialogCoreAndFallsBackToDialog() {
        let systemDialog = candidate(
            2,
            subrole: "AXSystemDialog",
            frame: CGRect(x: 300, y: 400, width: 118, height: 122)
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [candidate(1)]),
            .selected(
                memberIdentities: [1],
                frame: CGRect(x: 100, y: 200, width: 120, height: 110)
            )
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [systemDialog]),
            .selected(memberIdentities: [2], frame: systemDialog.frame)
        )
        XCTAssertEqual(
            PetWindowSelector.select(from: [systemDialog, candidate(1)]),
            .selected(memberIdentities: [2], frame: systemDialog.frame)
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

    func testTrackedFrameResolverUsesOnlyCoincidentSelectedFrames() throws {
        let first = CGRect(x: 100, y: 200, width: 120, height: 110)
        let coincident = CGRect(x: 100.2, y: 199.8, width: 120.2, height: 109.8)
        let resolved = try XCTUnwrap(PetTrackedFrameResolver.resolve([first, coincident]))

        XCTAssertEqual(resolved, CGRect(x: 100.1, y: 199.9, width: 120.1, height: 109.9))
        XCTAssertNil(PetTrackedFrameResolver.resolve([
            first,
            first.offsetBy(dx: 3, dy: 0),
        ]))
        XCTAssertNil(PetTrackedFrameResolver.resolve([.zero]))
    }

    func testIgnoresWideActivityDialogsWhenSelectingPetCore() {
        let pet = candidate(1)
        let activity = candidate(
            2,
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )

        XCTAssertEqual(
            PetWindowSelector.select(from: [activity, pet]),
            .selected(memberIdentities: [1], frame: pet.frame)
        )
    }

    func testActivityDialogAboveAndBelowResolveWithoutChangingPetSelection() {
        let pet = candidate(1)
        let above = candidate(2, frame: CGRect(x: 40, y: 80, width: 360, height: 70))
        let below = candidate(3, frame: CGRect(x: 40, y: 350, width: 360, height: 70))

        let aboveResolution = PetActivityGeometryResolver.resolve(
            petFrame: pet.frame,
            petMemberIdentities: [pet.identity],
            candidates: [pet, above]
        )
        XCTAssertEqual(aboveResolution.hint, .above)
        XCTAssertEqual(aboveResolution.activityVerticalDelta, 140)
        let belowResolution = PetActivityGeometryResolver.resolve(
            petFrame: pet.frame,
            petMemberIdentities: [pet.identity],
            candidates: [pet, below]
        )
        XCTAssertEqual(belowResolution.hint, .below)
        XCTAssertEqual(belowResolution.activityVerticalDelta, -130)
        XCTAssertEqual(
            PetWindowSelector.select(from: [pet, above, below]),
            .selected(memberIdentities: [pet.identity], frame: pet.frame)
        )
    }

    func testUniqueWideSystemDialogTakesPriorityAsActivityOrientationHint() {
        let pet = candidate(1)
        let legacyDialog = candidate(
            2,
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )
        let activity = candidate(
            3,
            subrole: "AXSystemDialog",
            frame: CGRect(x: 40, y: 260, width: 380, height: 60)
        )

        let resolution = PetActivityGeometryResolver.resolve(
            petFrame: pet.frame,
            petMemberIdentities: [pet.identity],
            candidates: [pet, legacyDialog, activity]
        )

        XCTAssertEqual(resolution.hint, .below)
        XCTAssertEqual(resolution.activityVerticalDelta, -35)
        XCTAssertEqual(resolution.observedIdentities, [2, 3])
        XCTAssertEqual(
            PetWindowSelector.select(from: [pet, legacyDialog, activity]),
            .selected(memberIdentities: [pet.identity], frame: pet.frame)
        )
    }

    func testMultipleWideSystemDialogsAreAmbiguousEvenWithLegacyFallback() {
        let pet = candidate(1)
        let legacyDialog = candidate(
            2,
            frame: CGRect(x: 40, y: 80, width: 360, height: 70)
        )
        let first = candidate(
            3,
            subrole: "AXSystemDialog",
            frame: CGRect(x: 40, y: 260, width: 380, height: 60)
        )
        let second = candidate(
            4,
            subrole: "AXSystemDialog",
            frame: CGRect(x: 40, y: 350, width: 380, height: 60)
        )

        let resolution = PetActivityGeometryResolver.resolve(
            petFrame: pet.frame,
            petMemberIdentities: [pet.identity],
            candidates: [pet, legacyDialog, first, second]
        )

        XCTAssertEqual(resolution.hint, .ambiguous)
        XCTAssertEqual(resolution.observedIdentities, [2, 3, 4])
    }

    func testMultipleActivityDialogsAreAmbiguousWithoutChangingPetSelection() {
        let pet = candidate(1)
        let first = candidate(2, frame: CGRect(x: 40, y: 80, width: 360, height: 70))
        let second = candidate(3, frame: CGRect(x: 40, y: 350, width: 360, height: 70))
        let resolution = PetActivityGeometryResolver.resolve(
            petFrame: pet.frame,
            petMemberIdentities: [pet.identity],
            candidates: [pet, first, second]
        )

        XCTAssertEqual(resolution.hint, .ambiguous)
        XCTAssertEqual(resolution.observedIdentities, [2, 3])
        XCTAssertEqual(
            PetWindowSelector.select(from: [pet, first, second]),
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

    func testTargetAndPlacementStatusExposeNoRawAccessibilityData() {
        XCTAssertEqual(HaloFollowingTargetSource.pet.statusText, "Target: Pet")
        XCTAssertEqual(
            HaloFollowingTargetSource.codexWindowFallback.statusText,
            "Target: Codex Window"
        )
        XCTAssertEqual(HaloFollowingTargetSource.freeFloating.statusText, "Target: Free-floating")
        XCTAssertEqual(PetTargetDiscoveryState.searching.statusText, "Pet: Searching")
        XCTAssertEqual(
            PetTargetDiscoveryState.unavailable.statusText,
            "Pet: Unavailable or Tucked Away"
        )
        XCTAssertEqual(PetTargetDiscoveryState.ambiguous.statusText, "Pet: Target Ambiguous")
        XCTAssertEqual(PetPlacementStatus.centered.statusText, "Pet placement: Centered")
        XCTAssertEqual(PetPlacementStatus.unavailable.statusText, "Pet placement: Unavailable")
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
