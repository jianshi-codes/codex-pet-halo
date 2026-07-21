import Foundation

public enum CodexReviewedProtocolSemantic: String, CaseIterable, Hashable, Sendable {
    case initializeHandshake
    case accountRead
    case rateLimitsRead
    case rateLimitsUpdated
    case accountUsageRead
    case jsonRPCEnvelopes
}

public struct CodexProtocolCompatibility: Equatable, Sendable {
    public let cliVersion: String
    public let schemaVersion: String
    public let reviewedSemantics: Set<CodexReviewedProtocolSemantic>

    public init(
        cliVersion: String,
        schemaVersion: String,
        reviewedSemantics: Set<CodexReviewedProtocolSemantic>
    ) {
        self.cliVersion = cliVersion
        self.schemaVersion = schemaVersion
        self.reviewedSemantics = reviewedSemantics
    }

    public var supportsProductionSemantics: Bool {
        reviewedSemantics == Set(CodexReviewedProtocolSemantic.allCases)
    }
}

public enum CodexCompatibilityRegistry {
    public static let supported: [String: CodexProtocolCompatibility] = [
        "0.145.0-alpha.18": CodexProtocolCompatibility(
            cliVersion: "0.145.0-alpha.18",
            schemaVersion: "0.145.0-alpha.18",
            reviewedSemantics: Set(CodexReviewedProtocolSemantic.allCases)
        ),
    ]

    public static func compatibility(for cliVersion: String) -> CodexProtocolCompatibility? {
        supported[cliVersion]
    }
}
