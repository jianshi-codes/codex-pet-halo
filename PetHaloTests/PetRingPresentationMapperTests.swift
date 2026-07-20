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
        XCTAssertEqual(current.weekly.value?.semanticLevel, .healthy)
        XCTAssertEqual(current.weekly.freshnessText, "Current")
        XCTAssertEqual(stale.weekly.freshnessText, "Stale")
        XCTAssertEqual(unavailable.weekly, .unavailable)
    }

    func testMetricAwareThresholdPolicyUsesExactBoundaries() {
        XCTAssertEqual(PetRingPresentationPolicy.remainingLevel(for: 50), .healthy)
        XCTAssertEqual(PetRingPresentationPolicy.remainingLevel(for: 49.9), .warning)
        XCTAssertEqual(PetRingPresentationPolicy.remainingLevel(for: 20), .warning)
        XCTAssertEqual(PetRingPresentationPolicy.remainingLevel(for: 19.9), .critical)
        XCTAssertEqual(PetRingPresentationPolicy.todayLevel(for: 0.5), .healthy)
        XCTAssertEqual(PetRingPresentationPolicy.todayLevel(for: 0.5001), .warning)
        XCTAssertEqual(PetRingPresentationPolicy.todayLevel(for: 0.8), .warning)
        XCTAssertEqual(PetRingPresentationPolicy.todayLevel(for: 0.8001), .critical)
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

        XCTAssertEqual(model.todayTokens?.value.tokenCount, 12_345)
        XCTAssertEqual(model.todayTokens?.value.tokenText, "12,345")
        XCTAssertEqual(model.todayTokens?.value.peakDailyTokenCount, 20_000)
        XCTAssertEqual(model.todayTokens?.value.progress, 0.61725)
        XCTAssertEqual(model.todayTokens?.freshnessText, "Current")
    }

    func testTodayIsOmittedForMissingBucketMissingPeakOrZeroPeak() {
        let missing = mapper().map(
            state(
                accountUsage: .available(accountUsage(buckets: [])),
                usageFreshness: .current
            ),
            date: date
        )
        let missingPeak = mapper().map(
            state(
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 10)],
                    peak: nil
                )),
                usageFreshness: .current
            ),
            date: date
        )
        let zeroPeak = mapper().map(
            state(
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 10)],
                    peak: 0
                )),
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertNil(missing.todayTokens)
        XCTAssertNil(missingPeak.todayTokens)
        XCTAssertNil(zeroPeak.todayTokens)
    }

    func testTodayProgressClampsAtOneAndPreservesActualTokenText() {
        let model = mapper().map(
            state(
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 26_479_888)],
                    peak: 20_000_000
                )),
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.todayTokens?.value.progress, 1)
        XCTAssertEqual(model.todayTokens?.value.tokenCount, 26_479_888)
        XCTAssertEqual(model.todayTokens?.value.tokenText, "26,479,888")
        XCTAssertEqual(model.todayTokens?.value.semanticLevel, .critical)
    }

    func testExplicitZeroTodayRendersZeroProgressWhenPeakExists() {
        let model = mapper().map(
            state(
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 0)]
                )),
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.todayTokens?.value.tokenText, "0")
        XCTAssertEqual(model.todayTokens?.value.progress, 0)
        XCTAssertEqual(model.todayTokens?.value.semanticLevel, .healthy)
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
        XCTAssertTrue(stale.accessibilityValue.contains("Today tokens, 99"))
        XCTAssertTrue(stale.accessibilityValue.contains("stale"))
    }

    func testUnavailableAccountUsageIsOmittedWithoutFabrication() {
        let model = mapper().map(state(), date: date)

        XCTAssertNil(model.todayTokens)
        XCTAssertFalse(model.accessibilityValue.contains("Today tokens"))
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

        XCTAssertEqual(geometry.panelSize, CGSize(width: 252, height: 252))
        XCTAssertEqual(geometry.transparentCenterDiameter, 162)
        XCTAssertGreaterThan(geometry.transparentCenterDiameter, 150)
        XCTAssertLessThan(geometry.outerRadius * 2, geometry.panelDiameter)
        XCTAssertEqual(geometry.radius(for: .weekly), 104)
        XCTAssertEqual(geometry.radius(for: .fiveHour), 94)
        XCTAssertEqual(geometry.radius(for: .today), 84)
        XCTAssertFalse(HaloSurfaceMode.petRing.usesCardBackground)
        XCTAssertFalse(HaloSurfaceMode.petRing.hasPanelShadow)
    }

    func testThreeRingProgressValuesAreIndependent() {
        let model = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 25, minutes: 10_080)),
                fiveHour: .available(quota(usedPercent: 60, minutes: 300)),
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 5_000)],
                    peak: 20_000
                )),
                rateFreshness: .current,
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.weekly.value?.progress, 0.75)
        XCTAssertEqual(model.fiveHour?.value?.progress, 0.4)
        XCTAssertEqual(model.todayTokens?.value.progress, 0.25)
    }

    func testLabelsAndOrientationDoNotChangeRingCenterGeometry() {
        let geometry = PetRingGeometry.standard
        let center = geometry.ringCenter(in: geometry.panelSize)

        XCTAssertEqual(center, CGPoint(x: 126, y: 126))
        XCTAssertEqual(
            geometry.ringCenter(in: geometry.panelSize),
            center
        )
        XCTAssertNotEqual(
            geometry.labelPosition(for: .weekly, orientation: .openingTop),
            geometry.labelPosition(for: .weekly, orientation: .openingBottom)
        )
        XCTAssertLessThan(
            geometry.labelPosition(for: .weekly, orientation: .openingTop).x,
            geometry.labelPosition(for: .fiveHour, orientation: .openingTop).x
        )
        XCTAssertLessThan(
            geometry.labelPosition(for: .fiveHour, orientation: .openingTop).x,
            geometry.labelPosition(for: .today, orientation: .openingTop).x
        )
        XCTAssertEqual(geometry.angles(for: .openingTop).sweepAngleDegrees, 260)
        XCTAssertEqual(geometry.angles(for: .openingBottom).sweepAngleDegrees, 260)
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

    private func accountUsage(
        buckets: [DailyAccountUsage],
        peak: UInt64? = 20_000
    ) -> AccountUsage {
        AccountUsage(
            summary: AccountUsageSummary(
                lifetimeTokenCount: 1_000_000,
                peakDailyTokenCount: peak,
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
