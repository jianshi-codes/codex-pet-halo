import XCTest
@testable import PetHaloCore

final class CodexProtocolCompatibilityTests: XCTestCase {
    func testEveryRegisteredVersionHasAllProductionSemanticsReviewed() throws {
        XCTAssertFalse(CodexCompatibilityRegistry.supported.isEmpty)

        for (version, compatibility) in CodexCompatibilityRegistry.supported {
            XCTAssertEqual(compatibility.cliVersion, version)
            XCTAssertTrue(compatibility.supportsProductionSemantics)
            XCTAssertEqual(
                compatibility.reviewedSemantics,
                Set(CodexReviewedProtocolSemantic.allCases)
            )
        }
    }

    func testUnregisteredVersionsRemainUnsupported() {
        XCTAssertNil(CodexCompatibilityRegistry.compatibility(for: "0.146.0"))
        XCTAssertNil(CodexCompatibilityRegistry.compatibility(for: "invalid"))
    }

    func testDecodingCompatibilityDoesNotImplyProductionCompatibility() {
        let incomplete = CodexProtocolCompatibility(
            cliVersion: "test",
            schemaVersion: "test",
            reviewedSemantics: [.jsonRPCEnvelopes]
        )

        XCTAssertFalse(incomplete.supportsProductionSemantics)
    }
}
