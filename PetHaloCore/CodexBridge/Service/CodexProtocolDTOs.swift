import Foundation

enum CodexProtocolDecodingError: Error, Equatable, Sendable {
    case invalidShape
}

struct AccountAvailabilityDTO: Decodable, Sendable {
    let accountAvailable: Bool
    let requiresOpenAIAuthentication: Bool

    enum CodingKeys: String, CodingKey {
        case account
        case requiresOpenaiAuth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requiresOpenAIAuthentication = try container.decode(Bool.self, forKey: .requiresOpenaiAuth)
        if container.contains(.account) {
            accountAvailable = !(try container.decodeNil(forKey: .account))
        } else {
            accountAvailable = false
        }
    }
}

struct RateLimitWindowDTO: Decodable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
}

struct RateLimitSnapshotDTO: Decodable, Sendable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindowDTO?
    let secondary: RateLimitWindowDTO?
}

struct RateLimitsResponseDTO: Decodable, Sendable {
    let rateLimits: RateLimitSnapshotDTO
    let rateLimitsByLimitId: [String: RateLimitSnapshotDTO]?
}

struct AccountUsageSummaryDTO: Decodable, Sendable {
    let lifetimeTokens: UInt64?
    let peakDailyTokens: UInt64?
    let longestRunningTurnSec: UInt64?
    let currentStreakDays: UInt64?
    let longestStreakDays: UInt64?
}

struct DailyAccountUsageDTO: Decodable, Sendable {
    let startDate: String
    let tokens: UInt64
}

struct AccountUsageResponseDTO: Decodable, Sendable {
    let summary: AccountUsageSummaryDTO
    let dailyUsageBuckets: [DailyAccountUsageDTO]?
}

enum CodexDTOCodec {
    static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) throws -> T {
        do {
            let data = try JSONEncoder().encode(value)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CodexProtocolDecodingError.invalidShape
        }
    }
}

enum CodexUsageNormalizer {
    static func rateLimitBuckets(from response: RateLimitsResponseDTO) -> [RateLimitBucket] {
        if let byID = response.rateLimitsByLimitId, !byID.isEmpty {
            return byID.keys.sorted().compactMap { id in
                guard let snapshot = byID[id] else { return nil }
                return bucket(id: id, snapshot: snapshot)
            }
        }

        guard let id = response.rateLimits.limitId, !id.isEmpty else {
            return []
        }
        return [bucket(id: id, snapshot: response.rateLimits)]
    }

    static func accountUsage(from response: AccountUsageResponseDTO) throws -> AccountUsage {
        let summary = AccountUsageSummary(
            lifetimeTokenCount: response.summary.lifetimeTokens,
            peakDailyTokenCount: response.summary.peakDailyTokens,
            longestRunningTurnSeconds: response.summary.longestRunningTurnSec,
            currentStreakDays: response.summary.currentStreakDays,
            longestStreakDays: response.summary.longestStreakDays
        )
        let daily: [DailyAccountUsage]? = try response.dailyUsageBuckets.map { buckets in
            try buckets.map { bucket -> DailyAccountUsage in
                guard let date = parseDateOnly(bucket.startDate) else {
                    throw CodexProtocolDecodingError.invalidShape
                }
                return DailyAccountUsage(date: date, tokenCount: bucket.tokens)
            }
        }
        return AccountUsage(summary: summary, dailyBuckets: daily)
    }

    private static func bucket(id: String, snapshot: RateLimitSnapshotDTO) -> RateLimitBucket {
        var windows: [QuotaWindow] = []
        if let primary = snapshot.primary {
            windows.append(window(primary, source: .primary))
        }
        if let secondary = snapshot.secondary {
            windows.append(window(secondary, source: .secondary))
        }
        return RateLimitBucket(id: id, displayName: snapshot.limitName, windows: windows)
    }

    private static func window(_ value: RateLimitWindowDTO, source: WindowSource) -> QuotaWindow {
        QuotaWindow(
            source: source,
            usedPercent: value.usedPercent,
            durationMinutes: value.windowDurationMins,
            resetsAt: value.resetsAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    private static func parseDateOnly(_ value: String) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
