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

    func testReviewedRegistryRemainsExactEvidenceOnly() {
        XCTAssertNil(CodexCompatibilityRegistry.compatibility(for: "0.146.0"))
        XCTAssertNil(CodexCompatibilityRegistry.compatibility(for: "invalid"))
    }

    func testVersionPolicyDistinguishesReviewedProvisionalAndBlockedVersions() {
        let policy = CodexCompatibilityPolicy()

        assertBlocked(policy.decision(for: "0.145.0-alpha.17"), reason: .tooOld)
        guard case let .reviewed(reviewed) = policy.decision(for: "0.145.0-alpha.18") else {
            return XCTFail("Expected exact reviewed version")
        }
        XCTAssertEqual(reviewed.cliVersion, "0.145.0-alpha.18")
        XCTAssertEqual(policy.decision(for: "0.145.0-alpha.19"), .provisional(version: "0.145.0-alpha.19"))
        XCTAssertEqual(policy.decision(for: "0.145.0-alpha.27"), .provisional(version: "0.145.0-alpha.27"))
        XCTAssertEqual(policy.decision(for: "0.146.0"), .provisional(version: "0.146.0"))
        XCTAssertEqual(policy.decision(for: "0.999.0"), .provisional(version: "0.999.0"))
        assertBlocked(policy.decision(for: "1.0.0"), reason: .majorBoundary)
        assertBlocked(policy.decision(for: "malformed"), reason: .malformed)
    }

    func testKnownIncompatibleVersionOverridesProvisionalRange() {
        let policy = CodexCompatibilityPolicy(knownIncompatibleVersions: ["0.146.7"])

        assertBlocked(policy.decision(for: "0.146.7"), reason: .knownIncompatible)
        XCTAssertEqual(policy.decision(for: "0.146.8"), .provisional(version: "0.146.8"))
    }

    func testSemanticVersionOrderingHandlesNumericPrereleaseIdentifiers() throws {
        let alpha18 = try XCTUnwrap(CodexCLIVersion("0.145.0-alpha.18"))
        let alpha27 = try XCTUnwrap(CodexCLIVersion("0.145.0-alpha.27"))
        let release = try XCTUnwrap(CodexCLIVersion("0.145.0"))
        let beta2 = try XCTUnwrap(CodexCLIVersion("0.150.0-beta.2"))
        let future = try XCTUnwrap(CodexCLIVersion("0.999.0"))

        XCTAssertLessThan(alpha18, alpha27)
        XCTAssertLessThan(alpha27, release)
        XCTAssertLessThan(release, beta2)
        XCTAssertLessThan(beta2, future)
    }

    func testMalformedSemanticVersionsAreRejected() {
        for value in ["", "0.145", "0.145.0-", "0.145.0-alpha..18", "0.0145.0", "0.145.0-alpha.018"] {
            XCTAssertNil(CodexCLIVersion(value), value)
        }
    }

    func testDecodingCompatibilityDoesNotImplyProductionCompatibility() {
        let incomplete = CodexProtocolCompatibility(
            cliVersion: "test",
            schemaVersion: "test",
            reviewedSemantics: [.jsonRPCEnvelopes]
        )

        XCTAssertFalse(incomplete.supportsProductionSemantics)
    }

    private func assertBlocked(
        _ decision: CodexCLIVersionDecision,
        reason: CodexVersionBlockReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .blocked(_, actualReason) = decision else {
            return XCTFail("Expected blocked decision, got \(decision)", file: file, line: line)
        }
        XCTAssertEqual(actualReason, reason, file: file, line: line)
    }
}
