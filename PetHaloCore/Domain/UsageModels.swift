import Foundation

public enum WindowSource: String, Equatable, Sendable {
    case primary
    case secondary
}

public struct QuotaWindow: Equatable, Sendable {
    public let source: WindowSource
    public let usedPercent: Double
    public let remainingPercent: Double
    public let durationMinutes: Int?
    public let resetsAt: Date?

    public init(
        source: WindowSource,
        usedPercent: Double,
        durationMinutes: Int?,
        resetsAt: Date?
    ) {
        let clampedUsed = min(max(usedPercent, 0), 100)
        self.source = source
        self.usedPercent = clampedUsed
        remainingPercent = min(max(100 - clampedUsed, 0), 100)
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
    }
}

public struct RateLimitBucket: Equatable, Sendable {
    public let id: String
    public let displayName: String?
    public let windows: [QuotaWindow]

    public init(id: String, displayName: String?, windows: [QuotaWindow]) {
        self.id = id
        self.displayName = displayName
        self.windows = windows
    }
}

public struct AccountUsageSummary: Equatable, Sendable {
    public let lifetimeTokenCount: UInt64?
    public let peakDailyTokenCount: UInt64?
    public let longestRunningTurnSeconds: UInt64?
    public let currentStreakDays: UInt64?
    public let longestStreakDays: UInt64?

    public init(
        lifetimeTokenCount: UInt64?,
        peakDailyTokenCount: UInt64?,
        longestRunningTurnSeconds: UInt64?,
        currentStreakDays: UInt64?,
        longestStreakDays: UInt64?
    ) {
        self.lifetimeTokenCount = lifetimeTokenCount
        self.peakDailyTokenCount = peakDailyTokenCount
        self.longestRunningTurnSeconds = longestRunningTurnSeconds
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
    }
}

public struct DailyAccountUsage: Equatable, Sendable {
    public let date: Date
    public let tokenCount: UInt64

    public init(date: Date, tokenCount: UInt64) {
        self.date = date
        self.tokenCount = tokenCount
    }
}

public struct AccountUsage: Equatable, Sendable {
    public let summary: AccountUsageSummary
    public let dailyBuckets: [DailyAccountUsage]?

    public init(summary: AccountUsageSummary, dailyBuckets: [DailyAccountUsage]?) {
        self.summary = summary
        self.dailyBuckets = dailyBuckets
    }
}

public struct ContextUsage: Equatable, Sendable {
    public let remainingPercent: Double

    public init(remainingPercent: Double) {
        self.remainingPercent = remainingPercent
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let rateLimitBuckets: [RateLimitBucket]
    public let accountUsage: AccountUsage?
    public let contextUsage: ContextUsage?
    public let collectedAt: Date

    public init(
        rateLimitBuckets: [RateLimitBucket],
        accountUsage: AccountUsage?,
        contextUsage: ContextUsage? = nil,
        collectedAt: Date
    ) {
        self.rateLimitBuckets = rateLimitBuckets
        self.accountUsage = accountUsage
        self.contextUsage = contextUsage
        self.collectedAt = collectedAt
    }
}

public enum SafeFailureReason: String, Equatable, Sendable {
    case executableMissing
    case versionInspectionFailed
    case unsupportedProtocolVersion
    case runtimeIncompatible
    case processLaunchFailed
    case transportClosed
    case requestTimedOut
    case protocolViolation
    case authenticationUnavailable
    case rateLimitsUnavailable
    case accountUsageUnsupported
    case accountUsageUnavailable
    case cancelled
}

public enum CapabilityUnavailableReason: String, Equatable, Sendable {
    case generalBucketMissing
    case matchingWindowMissing
    case ambiguousWindows
    case authenticationUnavailable
    case requestFailed
    case unsupported
}

public enum Capability<Value: Equatable & Sendable>: Equatable, Sendable {
    case available(Value)
    case unavailable(CapabilityUnavailableReason)
    case ambiguous
}

public struct UsageCapabilities: Equatable, Sendable {
    public let generalWeekly: Capability<QuotaWindow>
    public let generalFiveHour: Capability<QuotaWindow>
    public let accountUsage: Capability<AccountUsage>
    public let contextUsage: Capability<ContextUsage>

    public init(
        generalWeekly: Capability<QuotaWindow>,
        generalFiveHour: Capability<QuotaWindow>,
        accountUsage: Capability<AccountUsage>,
        contextUsage: Capability<ContextUsage> = .unavailable(.unsupported)
    ) {
        self.generalWeekly = generalWeekly
        self.generalFiveHour = generalFiveHour
        self.accountUsage = accountUsage
        self.contextUsage = contextUsage
    }

    public static let unavailable = UsageCapabilities(
        generalWeekly: .unavailable(.requestFailed),
        generalFiveHour: .unavailable(.requestFailed),
        accountUsage: .unavailable(.requestFailed)
    )
}

public enum BridgeConnectionState: Equatable, Sendable {
    case stopped
    case starting
    case connected
    case reconnecting(attempt: Int)
    case unavailable
}

public enum ProtocolCompatibilityState: Equatable, Sendable {
    case unknown
    case reviewed(version: String)
    case provisional(version: String)
    case blocked(version: String?)
    case runtimeIncompatible(version: String)
}

public enum DataFreshness: Equatable, Sendable {
    case unavailable
    case current
    case stale
}

public struct UsageComponentFreshness: Equatable, Sendable {
    public let rateLimits: DataFreshness
    public let accountUsage: DataFreshness

    public init(rateLimits: DataFreshness, accountUsage: DataFreshness) {
        self.rateLimits = rateLimits
        self.accountUsage = accountUsage
    }

    public static let unavailable = UsageComponentFreshness(
        rateLimits: .unavailable,
        accountUsage: .unavailable
    )
}

public struct CodexUsageState: Equatable, Sendable {
    public let connection: BridgeConnectionState
    public let compatibility: ProtocolCompatibilityState
    public let snapshot: UsageSnapshot?
    public let capabilities: UsageCapabilities
    public let componentFreshness: UsageComponentFreshness
    public let freshness: DataFreshness
    public let lastSuccessfulRefresh: Date?
    public let failureReason: SafeFailureReason?

    public init(
        connection: BridgeConnectionState,
        compatibility: ProtocolCompatibilityState,
        snapshot: UsageSnapshot?,
        capabilities: UsageCapabilities,
        componentFreshness: UsageComponentFreshness,
        lastSuccessfulRefresh: Date?,
        failureReason: SafeFailureReason?
    ) {
        self.connection = connection
        self.compatibility = compatibility
        self.snapshot = snapshot
        self.capabilities = capabilities
        self.componentFreshness = componentFreshness
        self.freshness = Self.globalFreshness(
            snapshot: snapshot,
            componentFreshness: componentFreshness
        )
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
        self.failureReason = failureReason
    }

    public static let stopped = CodexUsageState(
        connection: .stopped,
        compatibility: .unknown,
        snapshot: nil,
        capabilities: .unavailable,
        componentFreshness: .unavailable,
        lastSuccessfulRefresh: nil,
        failureReason: nil
    )

    private static func globalFreshness(
        snapshot: UsageSnapshot?,
        componentFreshness: UsageComponentFreshness
    ) -> DataFreshness {
        guard let snapshot else { return .unavailable }
        var included: [DataFreshness] = []
        if componentFreshness.rateLimits != .unavailable {
            included.append(componentFreshness.rateLimits)
        }
        if snapshot.accountUsage != nil {
            included.append(componentFreshness.accountUsage)
        }
        guard !included.isEmpty else { return .unavailable }
        return included.allSatisfy { $0 == .current } ? .current : .stale
    }
}

public enum UsageSemantics {
    public static let fiveHourMinutes = 300
    public static let weeklyMinutes = 10_080
    public static let generalBucketID = "codex"

    public static func window(
        durationMinutes: Int,
        in buckets: [RateLimitBucket]
    ) -> Capability<QuotaWindow> {
        guard let general = buckets.first(where: { $0.id == generalBucketID }) else {
            return .unavailable(.generalBucketMissing)
        }
        let matches = general.windows.filter { $0.durationMinutes == durationMinutes }
        if matches.count > 1 {
            return .ambiguous
        }
        guard let match = matches.first else {
            return .unavailable(.matchingWindowMissing)
        }
        return .available(match)
    }
}
