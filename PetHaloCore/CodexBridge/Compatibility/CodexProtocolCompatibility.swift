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

struct CodexCLIVersion: Hashable, Comparable, Sendable {
    enum PrereleaseIdentifier: Hashable, Comparable, Sendable {
        case numeric(Int)
        case text(String)

        static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.numeric(left), .numeric(right)):
                return left < right
            case (.numeric, .text):
                return true
            case (.text, .numeric):
                return false
            case let (.text(left), .text(right)):
                return left < right
            }
        }
    }

    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: [PrereleaseIdentifier]

    init?(_ value: String) {
        let releaseParts = value.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard releaseParts.count <= 2 else { return nil }

        let core = releaseParts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
              let major = Self.parseCoreNumber(core[0]),
              let minor = Self.parseCoreNumber(core[1]),
              let patch = Self.parseCoreNumber(core[2])
        else {
            return nil
        }

        var prerelease: [PrereleaseIdentifier] = []
        if releaseParts.count == 2 {
            let identifiers = releaseParts[1].split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            guard !identifiers.isEmpty else { return nil }
            for identifier in identifiers {
                guard !identifier.isEmpty,
                      identifier.utf8.allSatisfy({ byte in
                          (48 ... 57).contains(byte)
                              || (65 ... 90).contains(byte)
                              || (97 ... 122).contains(byte)
                              || byte == 45
                      })
                else {
                    return nil
                }
                if identifier.utf8.allSatisfy({ (48 ... 57).contains($0) }) {
                    guard identifier.count == 1 || identifier.first != "0",
                          let number = Int(identifier)
                    else {
                        return nil
                    }
                    prerelease.append(.numeric(number))
                } else {
                    prerelease.append(.text(String(identifier)))
                }
            }
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let leftCore = [lhs.major, lhs.minor, lhs.patch]
        let rightCore = [rhs.major, rhs.minor, rhs.patch]
        if leftCore != rightCore {
            return leftCore.lexicographicallyPrecedes(rightCore)
        }
        if lhs.prerelease.isEmpty {
            return false
        }
        if rhs.prerelease.isEmpty {
            return true
        }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func parseCoreNumber(_ value: Substring) -> Int? {
        guard !value.isEmpty,
              value.utf8.allSatisfy({ (48 ... 57).contains($0) }),
              value.count == 1 || value.first != "0"
        else {
            return nil
        }
        return Int(value)
    }
}

enum CodexVersionBlockReason: Equatable, Sendable {
    case malformed
    case tooOld
    case knownIncompatible
    case majorBoundary
}

enum CodexCLIVersionDecision: Equatable, Sendable {
    case reviewed(CodexProtocolCompatibility)
    case provisional(version: String)
    case blocked(version: String?, reason: CodexVersionBlockReason)
}

struct CodexCompatibilityPolicy: Sendable {
    static let minimumAcceptedVersion = "0.145.0-alpha.18"
    static let current = CodexCompatibilityPolicy()

    private let minimum = CodexCLIVersion(minimumAcceptedVersion)!
    private let knownIncompatible: Set<CodexCLIVersion>

    init(knownIncompatibleVersions: Set<String> = []) {
        knownIncompatible = Set(knownIncompatibleVersions.compactMap(CodexCLIVersion.init))
    }

    func decision(for value: String) -> CodexCLIVersionDecision {
        guard let version = CodexCLIVersion(value) else {
            return .blocked(version: nil, reason: .malformed)
        }
        if knownIncompatible.contains(version) {
            return .blocked(version: value, reason: .knownIncompatible)
        }
        if version < minimum {
            return .blocked(version: value, reason: .tooOld)
        }
        if version.major >= 1 {
            return .blocked(version: value, reason: .majorBoundary)
        }
        if let reviewed = CodexCompatibilityRegistry.compatibility(for: value),
           reviewed.supportsProductionSemantics
        {
            return .reviewed(reviewed)
        }
        return .provisional(version: value)
    }
}
