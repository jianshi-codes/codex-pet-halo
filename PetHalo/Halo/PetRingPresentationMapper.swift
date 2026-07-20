import Foundation
import PetHaloCore

struct PetRingPresentationMapper {
    private var calendar: Calendar
    private let locale: Locale
    private let compactTokenFormatter: CompactTokenFormatter

    init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
        compactTokenFormatter = CompactTokenFormatter(locale: locale)
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
            semanticLevel: PetRingPresentationPolicy.remainingLevel(
                for: window.remainingPercent
            )
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
        guard matches.count == 1,
              let bucket = matches.first,
              let peak = usage.summary.peakDailyTokenCount,
              peak > 0
        else {
            return nil
        }
        let ratio = Double(bucket.tokenCount) / Double(peak)
        let value = TodayTokenValue(
            tokenCount: bucket.tokenCount,
            tokenText: numberText(bucket.tokenCount),
            compactTokenText: compactTokenFormatter.string(from: bucket.tokenCount),
            peakDailyTokenCount: peak,
            peakTokenText: numberText(peak),
            consumptionRatio: ratio,
            semanticLevel: PetRingPresentationPolicy.todayLevel(for: ratio)
        )
        switch freshness {
        case .current:
            return .current(value)
        case .stale:
            return .stale(value)
        case .unavailable:
            return nil
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
        if let todayTokens {
            values.append(todayAccessibilityValue(todayTokens))
        }
        return values.joined(separator: "; ")
    }

    private func ringAccessibilityValue(
        name: String,
        metric: RingMetricPresentation
    ) -> String {
        guard let value = metric.value else { return "\(name), unavailable" }
        return "\(name), \(value.percentText) remaining, "
            + "\(metric.freshnessText.lowercased()), \(value.semanticLevel.text.lowercased())"
    }

    private func todayAccessibilityValue(_ metric: TodayTokenPresentation) -> String {
        let value = metric.value
        return "Today tokens, \(value.tokenText), \(value.percentOfPeakText) of historical peak, "
            + "\(metric.freshnessText.lowercased()), \(value.semanticLevel.text.lowercased())"
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
