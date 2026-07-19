import Foundation

public struct CodexProtocolCompatibility: Equatable, Sendable {
    public let cliVersion: String
    public let schemaVersion: String

    public init(cliVersion: String, schemaVersion: String) {
        self.cliVersion = cliVersion
        self.schemaVersion = schemaVersion
    }
}

public enum CodexCompatibilityRegistry {
    public static let supported: [String: CodexProtocolCompatibility] = [
        "0.145.0-alpha.18": CodexProtocolCompatibility(
            cliVersion: "0.145.0-alpha.18",
            schemaVersion: "0.145.0-alpha.18"
        ),
    ]

    public static func compatibility(for cliVersion: String) -> CodexProtocolCompatibility? {
        supported[cliVersion]
    }
}
