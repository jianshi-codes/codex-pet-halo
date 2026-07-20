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
        XCTAssertEqual(PetTargetDiscoveryState.unavailable.statusText, "Pet: Not Found")
        XCTAssertEqual(PetTargetDiscoveryState.ambiguous.statusText, "Pet: Ambiguous")
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
