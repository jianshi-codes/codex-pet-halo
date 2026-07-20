import XCTest
import PetHaloCore
@testable import PetHalo

final class PetRingPresentationMapperTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_753_008_000)
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    func testWeeklyUsesDomainRemainingPercentAndComponentFreshness() {
        let weekly = quota(usedPercent: 18.6, minutes: 10_080)
        let current = mapper().map(
            state(weekly: .available(weekly), rateFreshness: .current),
            date: date
        )
        let stale = mapper().map(
            state(weekly: .available(weekly), rateFreshness: .stale),
            date: date
        )
        let unavailable = mapper().map(state(), date: date)

        XCTAssertEqual(current.weekly.value?.remainingPercent, 81.4)
        XCTAssertEqual(current.weekly.value?.displayedPercent, 81)
        XCTAssertEqual(current.weekly.value?.remainingLevel, .normal)
        XCTAssertEqual(current.weekly.freshnessText, "Current")
        XCTAssertEqual(stale.weekly.freshnessText, "Stale")
        XCTAssertEqual(unavailable.weekly, .unavailable)
    }

    func testRemainingLevelsAreDeterministicAndNotColorOnly() {
        let low = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 80, minutes: 10_080)),
                rateFreshness: .current
            ),
            date: date
        )
        let critical = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 92, minutes: 10_080)),
                rateFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(low.weekly.value?.remainingLevel, .low)
        XCTAssertTrue(low.accessibilityValue.contains("low"))
        XCTAssertEqual(critical.weekly.value?.remainingLevel, .critical)
        XCTAssertTrue(critical.accessibilityValue.contains("critical"))
    }

    func testFiveHourAppearsOnlyForExactThreeHundredMinuteCapability() {
        let exact = mapper().map(
            state(
                fiveHour: .available(quota(usedPercent: 40, minutes: 300)),
                rateFreshness: .current
            ),
            date: date
        )
        let wrongDuration = mapper().map(
            state(
                fiveHour: .available(quota(usedPercent: 40, minutes: 301)),
                rateFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(exact.fiveHour?.value?.remainingPercent, 60)
        XCTAssertNil(wrongDuration.fiveHour)
    }

    func testTodayBucketMatchesInjectedCalendarDay() {
        let usage = accountUsage(buckets: [
            DailyAccountUsage(date: date.addingTimeInterval(-86_400), tokenCount: 1),
            DailyAccountUsage(date: date.addingTimeInterval(60), tokenCount: 12_345),
        ])
        let model = mapper().map(
            state(accountUsage: .available(usage), usageFreshness: .current),
            date: date
        )

        XCTAssertEqual(model.todayTokens?.value?.tokenCount, 12_345)
        XCTAssertEqual(model.todayTokens?.value?.tokenText, "12,345")
        XCTAssertEqual(model.todayTokens?.freshnessText, "Current")
    }

    func testMissingTodayBucketIsUnavailableAndExplicitZeroIsPreserved() {
        let missing = mapper().map(
            state(
                accountUsage: .available(accountUsage(buckets: [])),
                usageFreshness: .current
            ),
            date: date
        )
        let zero = mapper().map(
            state(
                accountUsage: .available(accountUsage(buckets: [
                    DailyAccountUsage(date: date, tokenCount: 0),
                ])),
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(missing.todayTokens, .unavailable)
        XCTAssertEqual(zero.todayTokens?.value?.tokenCount, 0)
        XCTAssertEqual(zero.todayTokens?.value?.tokenText, "0")
    }

    func testTodayTokensUseAccountUsageFreshnessIndependently() {
        let usage = accountUsage(buckets: [DailyAccountUsage(date: date, tokenCount: 99)])
        let stale = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 20, minutes: 10_080)),
                accountUsage: .available(usage),
                rateFreshness: .current,
                usageFreshness: .stale
            ),
            date: date
        )

        XCTAssertEqual(stale.weekly.freshnessText, "Current")
        XCTAssertEqual(stale.todayTokens?.freshnessText, "Stale")
        XCTAssertTrue(stale.accessibilityValue.contains("Today tokens, 99, stale"))
    }

    func testUnavailableAccountUsageIsOmittedWithoutFabrication() {
        let model = mapper().map(state(), date: date)

        XCTAssertNil(model.todayTokens)
        XCTAssertTrue(model.accessibilityValue.contains("Today tokens, unavailable"))
    }

    func testPetModelContainsNoDetailedAccountUsageFields() {
        let labels = Mirror(reflecting: PetRingPresentationModel.starting)
            .children.compactMap(\.label)

        XCTAssertEqual(labels, ["weekly", "fiveHour", "todayTokens", "accessibilityValue"])
        XCTAssertFalse(labels.contains("accountUsage"))
        XCTAssertFalse(labels.contains("summaryRows"))
        XCTAssertFalse(labels.contains("dailyRows"))
    }

    func testGeometryLeavesAValidatedTransparentCenter() {
        let geometry = PetRingGeometry.standard

        XCTAssertEqual(geometry.panelSize, CGSize(width: 208, height: 208))
        XCTAssertEqual(geometry.transparentCenterDiameter, 158)
        XCTAssertGreaterThan(geometry.transparentCenterDiameter, 120)
        XCTAssertLessThan(geometry.radius * 2, geometry.panelDiameter)
        XCTAssertFalse(HaloSurfaceMode.petRing.usesCardBackground)
        XCTAssertFalse(HaloSurfaceMode.petRing.hasPanelShadow)
    }

    private func mapper() -> PetRingPresentationMapper {
        PetRingPresentationMapper(
            calendar: Calendar(identifier: .gregorian),
            locale: locale,
            timeZone: timeZone
        )
    }

    private func quota(usedPercent: Double, minutes: Int) -> QuotaWindow {
        QuotaWindow(
            source: .primary,
            usedPercent: usedPercent,
            durationMinutes: minutes,
            resetsAt: nil
        )
    }

    private func accountUsage(buckets: [DailyAccountUsage]) -> AccountUsage {
        AccountUsage(
            summary: AccountUsageSummary(
                lifetimeTokenCount: 1_000_000,
                peakDailyTokenCount: 20_000,
                longestRunningTurnSeconds: 3_600,
                currentStreakDays: 2,
                longestStreakDays: 5
            ),
            dailyBuckets: buckets
        )
    }

    private func state(
        weekly: Capability<QuotaWindow> = .unavailable(.matchingWindowMissing),
        fiveHour: Capability<QuotaWindow> = .unavailable(.matchingWindowMissing),
        accountUsage: Capability<AccountUsage> = .unavailable(.unsupported),
        rateFreshness: DataFreshness = .unavailable,
        usageFreshness: DataFreshness = .unavailable
    ) -> CodexUsageState {
        let accountValue: AccountUsage?
        if case let .available(value) = accountUsage {
            accountValue = value
        } else {
            accountValue = nil
        }
        return CodexUsageState(
            connection: .connected,
            compatibility: .supported(version: "test"),
            snapshot: UsageSnapshot(
                rateLimitBuckets: [],
                accountUsage: accountValue,
                collectedAt: date
            ),
            capabilities: UsageCapabilities(
                generalWeekly: weekly,
                generalFiveHour: fiveHour,
                accountUsage: accountUsage
            ),
            componentFreshness: UsageComponentFreshness(
                rateLimits: rateFreshness,
                accountUsage: usageFreshness
            ),
            lastSuccessfulRefresh: date,
            failureReason: nil
        )
    }
}
