import XCTest
import PetHaloCore
@testable import PetHalo

final class HaloPresentationMapperTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_008_000)
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    func testCurrentWeeklyUsesRemainingPercentAndOmitsUnavailableOptionals() {
        let weekly = quota(usedPercent: 18.6, minutes: 10_080)
        let model = mapper().map(
            state(weekly: .available(weekly), rateFreshness: .current)
        )

        XCTAssertEqual(model.connectionState, .connected)
        XCTAssertEqual(model.weekly.value?.remainingPercent, 81.4)
        XCTAssertEqual(model.weekly.value?.displayedPercent, 81)
        XCTAssertEqual(model.weekly.statusText, "Current")
        XCTAssertNil(model.fiveHour)
        XCTAssertEqual(model.accountUsage, .unavailable)
    }

    func testStaleWeeklyRetainsValueAndUnavailableWeeklyKeepsConnectionDistinct() {
        let weekly = quota(usedPercent: 25, minutes: 10_080)
        let stale = mapper().map(
            state(weekly: .available(weekly), rateFreshness: .stale)
        )
        let connectedUnavailable = mapper().map(state())
        let bridgeUnavailable = mapper().map(state(connection: .unavailable))

        XCTAssertEqual(stale.weekly.value?.remainingText, "75%")
        XCTAssertEqual(stale.weekly.statusText, "Stale")
        XCTAssertEqual(connectedUnavailable.weekly, .unavailable)
        XCTAssertEqual(connectedUnavailable.connectionState, .connected)
        XCTAssertEqual(bridgeUnavailable.connectionState, .unavailable)
    }

    func testFiveHourAppearsOnlyForAvailableCapability() {
        let fiveHour = quota(usedPercent: 36.5, minutes: 300)
        let available = mapper().map(
            state(fiveHour: .available(fiveHour), rateFreshness: .current)
        )
        let ambiguous = mapper().map(state(fiveHour: .ambiguous))

        XCTAssertEqual(available.fiveHour?.value?.remainingText, "64%")
        XCTAssertNil(ambiguous.fiveHour)
    }

    func testPercentageRoundingCoversFractionalBoundsWithoutSecondConversion() {
        let nearZero = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 99.6, minutes: 10_080)),
                rateFreshness: .current
            )
        )
        let nearHundred = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 0.4, minutes: 10_080)),
                rateFreshness: .current
            )
        )
        let zero = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 100, minutes: 10_080)),
                rateFreshness: .current
            )
        )
        let hundred = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 0, minutes: 10_080)),
                rateFreshness: .current
            )
        )

        XCTAssertEqual(nearZero.weekly.value?.remainingText, "0%")
        XCTAssertEqual(nearHundred.weekly.value?.remainingText, "100%")
        XCTAssertEqual(zero.weekly.value?.remainingText, "0%")
        XCTAssertEqual(hundred.weekly.value?.remainingText, "100%")
    }

    func testResetFormattingHandlesMissingFutureAndPastDeterministically() {
        let missing = mappedQuota(reset: nil)
        let futureDate = now.addingTimeInterval(7_200)
        let future = mappedQuota(reset: futureDate)
        let past = mappedQuota(reset: now.addingTimeInterval(-60))

        XCTAssertEqual(missing.resetText, "Reset unavailable")
        XCTAssertEqual(missing.resetAccessibilityValue, "Unavailable")
        XCTAssertTrue(future.resetText.hasPrefix("Resets "))
        XCTAssertFalse(future.resetAccessibilityValue.isEmpty)
        XCTAssertEqual(past.resetText, "Reset due")
        XCTAssertFalse(past.resetText.contains("ago"))
    }

    func testAccountUsageShowsOnlyPresentFieldsAndOrdersLatestSevenDays() {
        let buckets = (0 ..< 9).reversed().map { day in
            DailyAccountUsage(
                date: now.addingTimeInterval(Double(day) * 86_400),
                tokenCount: UInt64(day + 1) * 1_000
            )
        }
        let usage = AccountUsage(
            summary: AccountUsageSummary(
                lifetimeTokenCount: nil,
                peakDailyTokenCount: 2_000,
                longestRunningTurnSeconds: nil,
                currentStreakDays: 3,
                longestStreakDays: nil
            ),
            dailyBuckets: buckets
        )
        let model = mapper().map(
            state(accountUsage: .available(usage), usageFreshness: .current)
        )

        guard case let .current(presentation) = model.accountUsage else {
            return XCTFail("Expected current Account Usage")
        }
        XCTAssertEqual(presentation.summaryRows.map(\.label), [
            "Peak daily tokens",
            "Current streak (days)",
        ])
        XCTAssertEqual(presentation.dailyRows.count, 7)
        XCTAssertEqual(presentation.dailyRows.map(\.date), presentation.dailyRows.map(\.date).sorted(by: >))
        XCTAssertEqual(presentation.dailyRows.first?.tokenText, "9,000")
    }

    func testComponentFreshnessDoesNotUseAggregateTimestampForAccountUsage() {
        let weekly = quota(usedPercent: 20, minutes: 10_080)
        let usage = accountUsage()
        let staleUsage = mapper().map(
            state(
                weekly: .available(weekly),
                accountUsage: .available(usage),
                rateFreshness: .current,
                usageFreshness: .stale,
                lastSuccessfulRefresh: now
            )
        )
        let unavailableOptionalUsage = mapper().map(
            state(
                weekly: .available(weekly),
                accountUsage: .unavailable(.unsupported),
                rateFreshness: .current,
                usageFreshness: .unavailable,
                lastSuccessfulRefresh: now
            )
        )
        let restored = mapper().map(
            state(
                weekly: .available(weekly),
                accountUsage: .available(usage),
                rateFreshness: .current,
                usageFreshness: .current,
                lastSuccessfulRefresh: now
            )
        )

        XCTAssertEqual(staleUsage.weekly.statusText, "Current")
        XCTAssertEqual(staleUsage.accountUsage.statusText, "Stale")
        XCTAssertEqual(unavailableOptionalUsage.weekly.statusText, "Current")
        XCTAssertEqual(unavailableOptionalUsage.accountUsage, .unavailable)
        XCTAssertEqual(restored.accountUsage.statusText, "Current")
    }

    func testPresentationModelContainsNeitherContextNorAccountIdentity() {
        let labels = Mirror(reflecting: HaloPresentationModel.starting).children.compactMap(\.label)

        XCTAssertFalse(labels.contains("context"))
        XCTAssertFalse(labels.contains("accountIdentity"))
        XCTAssertFalse(labels.contains("failureReason"))
    }

    private func mapper() -> HaloPresentationMapper {
        let fixedNow = now
        return HaloPresentationMapper(now: { fixedNow }, locale: locale, timeZone: timeZone)
    }

    private func mappedQuota(reset: Date?) -> QuotaPresentation {
        let model = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 25, minutes: 10_080, reset: reset)),
                rateFreshness: .current
            )
        )
        return model.weekly.value!
    }

    private func quota(
        usedPercent: Double,
        minutes: Int,
        reset: Date? = nil
    ) -> QuotaWindow {
        QuotaWindow(
            source: .primary,
            usedPercent: usedPercent,
            durationMinutes: minutes,
            resetsAt: reset
        )
    }

    private func accountUsage() -> AccountUsage {
        AccountUsage(
            summary: AccountUsageSummary(
                lifetimeTokenCount: 1,
                peakDailyTokenCount: nil,
                longestRunningTurnSeconds: nil,
                currentStreakDays: nil,
                longestStreakDays: nil
            ),
            dailyBuckets: nil
        )
    }

    private func state(
        connection: BridgeConnectionState = .connected,
        weekly: Capability<QuotaWindow> = .unavailable(.matchingWindowMissing),
        fiveHour: Capability<QuotaWindow> = .unavailable(.matchingWindowMissing),
        accountUsage: Capability<AccountUsage> = .unavailable(.unsupported),
        rateFreshness: DataFreshness = .unavailable,
        usageFreshness: DataFreshness = .unavailable,
        lastSuccessfulRefresh: Date? = nil
    ) -> CodexUsageState {
        let buckets: [RateLimitBucket]
        if case let .available(window) = weekly {
            var windows = [window]
            if case let .available(fiveHourWindow) = fiveHour {
                windows.append(fiveHourWindow)
            }
            buckets = [RateLimitBucket(id: "codex", displayName: nil, windows: windows)]
        } else if case let .available(fiveHourWindow) = fiveHour {
            buckets = [RateLimitBucket(id: "codex", displayName: nil, windows: [fiveHourWindow])]
        } else {
            buckets = []
        }
        let usageValue: AccountUsage?
        if case let .available(value) = accountUsage {
            usageValue = value
        } else {
            usageValue = nil
        }
        let snapshot = buckets.isEmpty && usageValue == nil ? nil : UsageSnapshot(
            rateLimitBuckets: buckets,
            accountUsage: usageValue,
            collectedAt: lastSuccessfulRefresh ?? now
        )
        return CodexUsageState(
            connection: connection,
            compatibility: .supported(version: "test"),
            snapshot: snapshot,
            capabilities: UsageCapabilities(
                generalWeekly: weekly,
                generalFiveHour: fiveHour,
                accountUsage: accountUsage
            ),
            componentFreshness: UsageComponentFreshness(
                rateLimits: rateFreshness,
                accountUsage: usageFreshness
            ),
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            failureReason: .accountUsageUnavailable
        )
    }
}
