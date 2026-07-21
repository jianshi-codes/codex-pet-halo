import XCTest
import PetHaloCore
@testable import PetHalo

final class PetRingPresentationMapperTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_753_008_000)
    private let locale = Locale(identifier: "en_US_POSIX")
    private let timeZone = TimeZone(secondsFromGMT: 0)!

    func testWeeklyResetFlowsAsDateWhileFiveHourPresentationStaysUnchanged() throws {
        let reset = try instant("2026-07-27T00:00:00Z")
        let model = mapper().map(
            state(
                weekly: .available(quota(
                    usedPercent: 61,
                    minutes: 10_080,
                    resetsAt: reset
                )),
                fiveHour: .available(quota(
                    usedPercent: 42,
                    minutes: 300,
                    resetsAt: reset
                )),
                rateFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.weekly.value?.resetsAt, reset)
        XCTAssertNil(model.fiveHour?.value?.resetsAt)
        XCTAssertEqual(model.fiveHour?.value?.percentText, "58%")
    }

    func testNilWeeklyResetPreservesOriginalVisibleAndAccessibilityText() {
        let formatter = resetFormatter(timeZone: timeZone)
        let model = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 61, minutes: 10_080)),
                rateFreshness: .current
            ),
            date: date
        )

        XCTAssertNil(model.weekly.value?.resetsAt)
        XCTAssertEqual(
            formatter.visibleValue(
                percentText: model.weekly.value?.percentText ?? "",
                resetsAt: model.weekly.value?.resetsAt
            ),
            "39%"
        )
        XCTAssertEqual(
            model.accessibilityValue,
            "Weekly quota, 39% remaining, current, warning"
        )
    }

    func testCompactWeeklyResetUsesInjectedLocalTimeZoneAcrossDateBoundaries() throws {
        let formatter = resetFormatter(
            timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        )

        XCTAssertEqual(
            formatter.visibleValue(
                percentText: "39%",
                resetsAt: try instant("2026-07-27T00:00:00Z")
            ),
            "39% · Jul 27"
        )
        XCTAssertEqual(
            formatter.visibleValue(
                percentText: "39%",
                resetsAt: try instant("2026-07-31T17:00:00Z")
            ),
            "39% · Aug 1"
        )
        XCTAssertEqual(
            formatter.visibleValue(
                percentText: "100%",
                resetsAt: try instant("2026-09-29T16:00:00Z")
            ),
            "100% · Sep 30"
        )
        XCTAssertEqual(
            formatter.visibleValue(
                percentText: "39%",
                resetsAt: try instant("2026-12-31T17:00:00Z")
            ),
            "39% · Jan 1"
        )

        let localizedAccessibility = WeeklyResetDateFormatter(
            accessibilityLocale: Locale(identifier: "fr_FR"),
            timeZone: timeZone
        )
        XCTAssertEqual(
            localizedAccessibility.visibleValue(
                percentText: "39%",
                resetsAt: try instant("2026-07-27T00:00:00Z")
            ),
            "39% · Jul 27"
        )
    }

    func testWeeklyAccessibilityIncludesExactLocalResetAndPreservesStaleSemantics() throws {
        let resetTimeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let reset = try instant("2026-07-27T00:00:00Z")
        let current = mapper(resetTimeZone: resetTimeZone).map(
            state(
                weekly: .available(quota(
                    usedPercent: 61,
                    minutes: 10_080,
                    resetsAt: reset
                )),
                rateFreshness: .current
            ),
            date: date
        )
        let stale = mapper(resetTimeZone: resetTimeZone).map(
            state(
                weekly: .available(quota(
                    usedPercent: 61,
                    minutes: 10_080,
                    resetsAt: reset
                )),
                rateFreshness: .stale
            ),
            date: date
        )

        XCTAssertEqual(
            current.accessibilityValue,
            "Weekly quota, 39% remaining, resets July 27, 2026 at 8:00\u{202F}AM GMT+8, "
                + "current, warning"
        )
        XCTAssertEqual(stale.weekly.value?.resetsAt, reset)
        XCTAssertTrue(stale.accessibilityValue.contains("resets July 27, 2026 at 8:00\u{202F}AM GMT+8"))
        XCTAssertTrue(stale.accessibilityValue.hasSuffix("stale, warning"))
    }

    func testPastWeeklyResetIsRenderedWithoutInferringQuotaState() throws {
        let pastReset = try instant("2024-01-01T00:00:00Z")
        let model = mapper().map(
            state(
                weekly: .available(quota(
                    usedPercent: 10,
                    minutes: 10_080,
                    resetsAt: pastReset
                )),
                rateFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.weekly.value?.resetsAt, pastReset)
        XCTAssertEqual(model.weekly.freshnessText, "Current")
        XCTAssertEqual(model.weekly.value?.remainingPercent, 90)
    }

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

    func testTodayUsesUTCAccountDayAcrossLocalMidnight() throws {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3_600))
        let localAfterMidnight = try XCTUnwrap(localCalendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 21,
            hour: 0,
            minute: 15
        )))
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = timeZone
        let accountDay = try XCTUnwrap(utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20
        )))
        let usage = accountUsage(buckets: [
            DailyAccountUsage(date: accountDay.addingTimeInterval(-86_400), tokenCount: 1),
            DailyAccountUsage(date: accountDay, tokenCount: 12_345),
        ])
        let model = PetRingPresentationMapper(
            calendar: Calendar(identifier: .gregorian),
            locale: locale
        ).map(
            state(accountUsage: .available(usage), usageFreshness: .current),
            date: localAfterMidnight
        )

        XCTAssertEqual(model.todayTokens?.value.tokenCount, 12_345)
        XCTAssertEqual(model.todayTokens?.value.tokenText, "12,345")
        XCTAssertEqual(model.todayTokens?.value.compactTokenText, "12.3K")
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
        XCTAssertEqual(model.todayTokens?.value.compactTokenText, "26.5M")
        XCTAssertEqual(model.todayTokens?.value.percentOfPeakText, "132%")
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
        XCTAssertEqual(model.todayTokens?.value.compactTokenText, "0")
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

    func testCompactTokenFormatterUsesLocalizedKMBValues() {
        let formatter = CompactTokenFormatter(locale: locale)

        XCTAssertEqual(formatter.string(from: 999), "999")
        XCTAssertEqual(formatter.string(from: 1_000), "1K")
        XCTAssertEqual(formatter.string(from: 1_200), "1.2K")
        XCTAssertEqual(formatter.string(from: 1_000_000), "1M")
        XCTAssertEqual(formatter.string(from: 50_570_762), "50.6M")
        XCTAssertEqual(formatter.string(from: 2_340_000_000), "2.3B")
        XCTAssertEqual(
            CompactTokenFormatter(locale: Locale(identifier: "de_DE"))
                .string(from: 1_500),
            "1,5K"
        )
    }

    func testTodayAccessibilityRetainsExactCountWhileVisibleValueIsCompact() {
        let model = mapper().map(
            state(
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 50_570_762)],
                    peak: 80_000_000
                )),
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(model.todayTokens?.value.compactTokenText, "50.6M")
        XCTAssertEqual(model.todayTokens?.value.percentOfPeakText, "63%")
        XCTAssertTrue(model.accessibilityValue.contains("50,570,762"))
        XCTAssertFalse(model.accessibilityValue.contains("50.6M"))
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

        XCTAssertEqual(geometry.panelSize, CGSize(width: 448, height: 252))
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

    func testIdentityDotPaletteIsFixedAndIndependentFromSharedStatusColor() {
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        let identityColors = metrics.map(PetRingPresentationPolicy.identityColor(for:))
        let model = mapper().map(
            state(
                weekly: .available(quota(usedPercent: 25, minutes: 10_080)),
                fiveHour: .available(quota(usedPercent: 25, minutes: 300)),
                accountUsage: .available(accountUsage(
                    buckets: [DailyAccountUsage(date: date, tokenCount: 5_000)],
                    peak: 20_000
                )),
                rateFreshness: .current,
                usageFreshness: .current
            ),
            date: date
        )

        XCTAssertEqual(identityColors.map(\.hex), ["#5865F2", "#00B8D9", "#A855F7"])
        XCTAssertEqual(Set(identityColors.map(\.hex)).count, 3)
        XCTAssertEqual(
            [
                model.weekly.value?.semanticLevel,
                model.fiveHour?.value?.semanticLevel,
                model.todayTokens?.value.semanticLevel,
            ],
            [.healthy, .healthy, .healthy]
        )
    }

    func testLabelsAndOrientationDoNotChangeRingCenterGeometry() {
        let geometry = PetRingGeometry.standard
        let center = geometry.ringCenter(in: geometry.panelSize)

        XCTAssertEqual(center, CGPoint(x: 224, y: 126))
        XCTAssertEqual(
            geometry.ringCenter(in: geometry.panelSize),
            center
        )
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        let panelBounds = CGRect(origin: .zero, size: geometry.panelSize)
        for metric in metrics {
            let right = geometry.labelPosition(
                for: metric,
                side: .right,
                visibleMetrics: metrics
            )
            let left = geometry.labelPosition(
                for: metric,
                side: .left,
                visibleMetrics: metrics
            )
            XCTAssertEqual(right.x + left.x, geometry.panelSize.width, accuracy: 0.001)
            XCTAssertEqual(right.y, left.y, accuracy: 0.001)
            XCTAssertTrue(panelBounds.contains(
                geometry.labelFrame(for: metric, side: .right, visibleMetrics: metrics)
            ))
            XCTAssertTrue(panelBounds.contains(
                geometry.labelFrame(for: metric, side: .left, visibleMetrics: metrics)
            ))
        }
        let topFrames = metrics.map {
            geometry.labelFrame(for: $0, side: .right, visibleMetrics: metrics)
        }
        XCTAssertEqual(Set(topFrames.map(\.minX)).count, 1)
        XCTAssertGreaterThan(topFrames[0].minX, center.x + geometry.outerRadius)
        XCTAssertFalse(topFrames[0].intersects(topFrames[1]))
        XCTAssertFalse(topFrames[0].intersects(topFrames[2]))
        XCTAssertFalse(topFrames[1].intersects(topFrames[2]))
        let bottomFrames = metrics.map {
            geometry.labelFrame(for: $0, side: .left, visibleMetrics: metrics)
        }
        XCTAssertEqual(Set(bottomFrames.map(\.maxX)).count, 1)
        XCTAssertLessThan(bottomFrames[0].maxX, center.x - geometry.outerRadius)
        XCTAssertFalse(bottomFrames[0].intersects(bottomFrames[1]))
        XCTAssertFalse(bottomFrames[0].intersects(bottomFrames[2]))
        XCTAssertFalse(bottomFrames[1].intersects(bottomFrames[2]))
        XCTAssertEqual(
            metrics.map {
                geometry.labelPosition(for: $0, side: .right, visibleMetrics: metrics).y
            },
            [156, 126, 96]
        )
        XCTAssertGreaterThan(geometry.radius(for: .weekly), geometry.radius(for: .fiveHour))
        XCTAssertGreaterThan(geometry.radius(for: .fiveHour), geometry.radius(for: .today))
        for metric in metrics {
            let right = geometry.connectorSegment(
                for: metric,
                side: .right,
                visibleMetrics: metrics
            )
            let left = geometry.connectorSegment(
                for: metric,
                side: .left,
                visibleMetrics: metrics
            )
            XCTAssertNotEqual(right.ringPoint, right.capsulePoint)
            XCTAssertEqual(right.ringPoint.x + left.ringPoint.x, geometry.panelSize.width, accuracy: 0.001)
            XCTAssertEqual(right.capsulePoint.x + left.capsulePoint.x, geometry.panelSize.width, accuracy: 0.001)
            XCTAssertEqual(right.ringPoint.y, left.ringPoint.y, accuracy: 0.001)
            XCTAssertEqual(right.capsulePoint.y, left.capsulePoint.y, accuracy: 0.001)
            XCTAssertTrue(panelBounds.contains(right.ringPoint))
            XCTAssertTrue(panelBounds.contains(right.capsulePoint))
            XCTAssertTrue(panelBounds.contains(left.ringPoint))
            XCTAssertTrue(panelBounds.contains(left.capsulePoint))
            let rightDelta = CGPoint(
                x: right.ringPoint.x - center.x,
                y: right.ringPoint.y - center.y
            )
            XCTAssertEqual(
                hypot(rightDelta.x, rightDelta.y),
                geometry.radius(for: metric),
                accuracy: 0.001
            )
            XCTAssertLessThan(right.ringPoint.x, right.capsulePoint.x)
            XCTAssertGreaterThan(left.ringPoint.x, left.capsulePoint.x)
        }
        XCTAssertEqual(geometry.angles(for: .openingTop).sweepAngleDegrees, 260)
        XCTAssertEqual(geometry.angles(for: .openingBottom).sweepAngleDegrees, 260)
    }

    #if DEBUG
    func testDebugOrientationPreviewAffectsOnlyEffectiveAngles() {
        XCTAssertEqual(
            PetRingOrientationPreview.from(arguments: ["app"]),
            .auto
        )
        XCTAssertEqual(
            PetRingOrientationPreview.from(arguments: [
                "app", "--pet-ring-orientation=gap-above",
            ]),
            .forceGapAbove
        )
        XCTAssertEqual(
            PetRingOrientationPreview.from(arguments: [
                "app", "--pet-ring-orientation=gap-below",
            ]),
            .forceGapBelow
        )
        XCTAssertEqual(
            PetRingOrientationPreview.forceGapAbove.orientation(auto: .openingBottom),
            .openingTop
        )
        XCTAssertEqual(
            PetRingOrientationPreview.forceGapBelow.orientation(auto: .openingTop),
            .openingBottom
        )
    }
    #endif

    private func mapper(resetTimeZone: TimeZone? = nil) -> PetRingPresentationMapper {
        PetRingPresentationMapper(
            calendar: Calendar(identifier: .gregorian),
            locale: locale,
            timeZone: timeZone,
            weeklyResetDateFormatter: resetFormatter(
                timeZone: resetTimeZone ?? timeZone
            )
        )
    }

    private func resetFormatter(timeZone: TimeZone) -> WeeklyResetDateFormatter {
        WeeklyResetDateFormatter(
            visibleLocale: locale,
            accessibilityLocale: locale,
            timeZone: timeZone
        )
    }

    private func instant(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    private func quota(
        usedPercent: Double,
        minutes: Int,
        resetsAt: Date? = nil
    ) -> QuotaWindow {
        QuotaWindow(
            source: .primary,
            usedPercent: usedPercent,
            durationMinutes: minutes,
            resetsAt: resetsAt
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
