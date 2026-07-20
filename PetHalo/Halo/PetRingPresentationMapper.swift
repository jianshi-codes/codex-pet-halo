import Foundation
import PetHaloCore

struct PetRingPresentationMapper {
    private var calendar: Calendar
    private let locale: Locale

    init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
    }

    func map(_ state: CodexUsageState, date: Date) -> PetRingPresentationModel {
        let weekly = ringMetric(
            capability: state.capabilities.generalWeekly,
            freshness: state.componentFreshness.rateLimits
        )
        let fiveHour = fiveHourMetric(
            capability: state.capabilities.generalFiveHour,
            freshness: state.componentFreshness.rateLimits
        )
        let todayTokens = todayTokenMetric(
            capability: state.capabilities.accountUsage,
            freshness: state.componentFreshness.accountUsage,
            date: date
        )
        return PetRingPresentationModel(
            weekly: weekly,
            fiveHour: fiveHour,
            todayTokens: todayTokens,
            accessibilityValue: accessibilityValue(
                weekly: weekly,
                fiveHour: fiveHour,
                todayTokens: todayTokens
            )
        )
    }

    private func fiveHourMetric(
        capability: Capability<QuotaWindow>,
        freshness: DataFreshness
    ) -> RingMetricPresentation? {
        guard case let .available(window) = capability,
              window.durationMinutes == UsageSemantics.fiveHourMinutes
        else {
            return nil
        }
        return ringMetric(window: window, freshness: freshness)
    }

    private func ringMetric(
        capability: Capability<QuotaWindow>,
        freshness: DataFreshness
    ) -> RingMetricPresentation {
        guard case let .available(window) = capability else { return .unavailable }
        return ringMetric(window: window, freshness: freshness)
    }

    private func ringMetric(
        window: QuotaWindow,
        freshness: DataFreshness
    ) -> RingMetricPresentation {
        let value = RingMetricValue(
            remainingPercent: window.remainingPercent,
            displayedPercent: Int(window.remainingPercent.rounded(.toNearestOrAwayFromZero)),
            remainingLevel: RemainingLevel(remainingPercent: window.remainingPercent)
        )
        switch freshness {
        case .current:
            return .current(value)
        case .stale:
            return .stale(value)
        case .unavailable:
            return .unavailable
        }
    }

    private func todayTokenMetric(
        capability: Capability<AccountUsage>,
        freshness: DataFreshness,
        date: Date
    ) -> TodayTokenPresentation? {
        guard case let .available(usage) = capability else { return nil }
        let matches = (usage.dailyBuckets ?? []).filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        guard matches.count == 1, let bucket = matches.first else {
            return .unavailable
        }
        let value = TodayTokenValue(
            tokenCount: bucket.tokenCount,
            tokenText: numberText(bucket.tokenCount)
        )
        switch freshness {
        case .current:
            return .current(value)
        case .stale:
            return .stale(value)
        case .unavailable:
            return .unavailable
        }
    }

    private func accessibilityValue(
        weekly: RingMetricPresentation,
        fiveHour: RingMetricPresentation?,
        todayTokens: TodayTokenPresentation?
    ) -> String {
        var values = [ringAccessibilityValue(name: "Weekly quota", metric: weekly)]
        if let fiveHour {
            values.append(ringAccessibilityValue(name: "Five-hour quota", metric: fiveHour))
        }
        values.append(todayAccessibilityValue(todayTokens))
        return values.joined(separator: "; ")
    }

    private func ringAccessibilityValue(
        name: String,
        metric: RingMetricPresentation
    ) -> String {
        guard let value = metric.value else { return "\(name), unavailable" }
        return "\(name), \(value.percentText) remaining, "
            + "\(metric.freshnessText.lowercased()), \(value.remainingLevel.text.lowercased())"
    }

    private func todayAccessibilityValue(_ metric: TodayTokenPresentation?) -> String {
        guard let metric else { return "Today tokens, unavailable" }
        guard let value = metric.value else { return "Today tokens, unavailable" }
        return "Today tokens, \(value.tokenText), \(metric.freshnessText.lowercased())"
    }

    private func numberText(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
