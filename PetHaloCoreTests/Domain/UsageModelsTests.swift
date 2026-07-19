import XCTest
@testable import PetHaloCore

final class UsageModelsTests: XCTestCase {
    func testUsedToRemainingConversionClampsAtBothBounds() {
        let over = QuotaWindow(
            source: .primary,
            usedPercent: 120,
            durationMinutes: 300,
            resetsAt: nil
        )
        let under = QuotaWindow(
            source: .secondary,
            usedPercent: -10,
            durationMinutes: 10_080,
            resetsAt: nil
        )

        XCTAssertEqual(over.usedPercent, 100)
        XCTAssertEqual(over.remainingPercent, 0)
        XCTAssertEqual(under.usedPercent, 0)
        XCTAssertEqual(under.remainingPercent, 100)
        XCTAssertEqual(over.source, .primary)
        XCTAssertEqual(under.source, .secondary)
    }

    func testSemanticWindowsUseExactDurationAndExactGeneralBucket() {
        let buckets = [
            RateLimitBucket(
                id: "model-specific",
                displayName: nil,
                windows: [window(minutes: 300, source: .primary)]
            ),
            RateLimitBucket(
                id: "codex",
                displayName: "General",
                windows: [
                    window(minutes: 10_080, source: .primary),
                    window(minutes: 300, source: .secondary),
                ]
            ),
        ]

        XCTAssertEqual(
            UsageSemantics.window(durationMinutes: 300, in: buckets),
            .available(window(minutes: 300, source: .secondary))
        )
        XCTAssertEqual(
            UsageSemantics.window(durationMinutes: 10_080, in: buckets),
            .available(window(minutes: 10_080, source: .primary))
        )
    }

    func testNoMapOrderFallbackAndAmbiguousWindowsAreUnavailable() {
        let noGeneral = [
            RateLimitBucket(
                id: "first",
                displayName: nil,
                windows: [window(minutes: 10_080, source: .primary)]
            ),
        ]
        XCTAssertEqual(
            UsageSemantics.window(durationMinutes: 10_080, in: noGeneral),
            .unavailable(.generalBucketMissing)
        )

        let ambiguous = [
            RateLimitBucket(
                id: "codex",
                displayName: nil,
                windows: [
                    window(minutes: 10_080, source: .primary),
                    window(minutes: 10_080, source: .secondary),
                ]
            ),
        ]
        XCTAssertEqual(
            UsageSemantics.window(durationMinutes: 10_080, in: ambiguous),
            .ambiguous
        )
    }

    func testUnknownFieldsNullableUsageAndAllBucketsNormalize() throws {
        let value: JSONValue = .object([
            "rateLimits": snapshot(id: "legacy", primaryMinutes: nil, secondaryMinutes: nil),
            "rateLimitsByLimitId": .object([
                "codex": snapshot(id: "codex", primaryMinutes: 10_080, secondaryMinutes: nil),
                "other": snapshot(id: "other", primaryMinutes: nil, secondaryMinutes: 300),
            ]),
            "rateLimitResetCredits": .null,
            "futureField": .string("ignored"),
        ])

        let response = try CodexDTOCodec.decode(RateLimitsResponseDTO.self, from: value)
        let buckets = CodexUsageNormalizer.rateLimitBuckets(from: response)

        XCTAssertEqual(buckets.map(\.id), ["codex", "other"])
        XCTAssertEqual(buckets[0].windows.first?.durationMinutes, 10_080)
        XCTAssertNil(buckets[0].windows.first?.resetsAt)
        XCTAssertEqual(buckets[1].windows.first?.source, .secondary)
    }

    func testAccountUsageAllowsNullSummaryFieldsAndOptionalDailyBuckets() throws {
        let value: JSONValue = .object([
            "summary": .object([
                "lifetimeTokens": .null,
                "peakDailyTokens": .unsigned(20),
                "longestRunningTurnSec": .null,
                "currentStreakDays": .unsigned(2),
                "longestStreakDays": .null,
                "unknown": .bool(true),
            ]),
            "dailyUsageBuckets": .null,
        ])

        let response = try CodexDTOCodec.decode(AccountUsageResponseDTO.self, from: value)
        let usage = try CodexUsageNormalizer.accountUsage(from: response)

        XCTAssertNil(usage.summary.lifetimeTokenCount)
        XCTAssertEqual(usage.summary.peakDailyTokenCount, 20)
        XCTAssertNil(usage.dailyBuckets)
    }

    func testInvalidRequiredDailyDateFailsInsteadOfDroppingBucket() throws {
        let value: JSONValue = .object([
            "summary": .object([
                "lifetimeTokens": .null,
                "peakDailyTokens": .null,
                "longestRunningTurnSec": .null,
                "currentStreakDays": .null,
                "longestStreakDays": .null,
            ]),
            "dailyUsageBuckets": .array([
                .object([
                    "startDate": .string("not-a-date"),
                    "tokens": .unsigned(10),
                ]),
            ]),
        ])
        let response = try CodexDTOCodec.decode(AccountUsageResponseDTO.self, from: value)

        XCTAssertThrowsError(try CodexUsageNormalizer.accountUsage(from: response)) { error in
            XCTAssertEqual(error as? CodexProtocolDecodingError, .invalidShape)
        }
    }

    private func window(minutes: Int?, source: WindowSource) -> QuotaWindow {
        QuotaWindow(source: source, usedPercent: 25, durationMinutes: minutes, resetsAt: nil)
    }

    private func snapshot(
        id: String,
        primaryMinutes: Int?,
        secondaryMinutes: Int?
    ) -> JSONValue {
        .object([
            "limitId": .string(id),
            "limitName": .null,
            "primary": primaryMinutes.map(windowValue) ?? .null,
            "secondary": secondaryMinutes.map(windowValue) ?? .null,
            "future": .object(["nested": .bool(true)]),
        ])
    }

    private func windowValue(_ minutes: Int) -> JSONValue {
        .object([
            "usedPercent": .double(25),
            "windowDurationMins": .integer(Int64(minutes)),
            "resetsAt": .null,
        ])
    }
}
