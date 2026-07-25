import Foundation
import PetHaloCore

struct PetRingPresentationMapper {
    private let weeklyResetDateFormatter: WeeklyResetDateFormatter

    init(
        weeklyResetDateFormatter: WeeklyResetDateFormatter = WeeklyResetDateFormatter()
    ) {
        self.weeklyResetDateFormatter = weeklyResetDateFormatter
    }

    func map(_ state: CodexUsageState) -> PetRingPresentationModel {
        let weekly = weeklyMetric(
            capability: state.capabilities.generalWeekly,
            freshness: state.componentFreshness.rateLimits
        )
        let fiveHour = fiveHourMetric(
            capability: state.capabilities.generalFiveHour,
            freshness: state.componentFreshness.rateLimits
        )
        return PetRingPresentationModel(
            weekly: weekly,
            fiveHour: fiveHour,
            accessibilityValue: accessibilityValue(
                weekly: weekly,
                fiveHour: fiveHour
            )
        )
    }

    private func weeklyMetric(
        capability: Capability<QuotaWindow>,
        freshness: DataFreshness
    ) -> RingMetricPresentation {
        guard case let .available(window) = capability else { return .unavailable }
        return ringMetric(
            window: window,
            freshness: freshness,
            resetsAt: window.resetsAt
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
        return ringMetric(window: window, freshness: freshness, resetsAt: nil)
    }

    private func ringMetric(
        window: QuotaWindow,
        freshness: DataFreshness,
        resetsAt: Date?
    ) -> RingMetricPresentation {
        let value = RingMetricValue(
            remainingPercent: window.remainingPercent,
            displayedPercent: Int(window.remainingPercent.rounded(.toNearestOrAwayFromZero)),
            semanticLevel: PetRingPresentationPolicy.remainingLevel(
                for: window.remainingPercent
            ),
            resetsAt: resetsAt
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
        fiveHour: RingMetricPresentation?
    ) -> String {
        var values = [ringAccessibilityValue(name: "Weekly quota", metric: weekly)]
        if let fiveHour {
            values.append(ringAccessibilityValue(name: "Five-hour quota", metric: fiveHour))
        }
        return values.joined(separator: "; ")
    }

    private func ringAccessibilityValue(
        name: String,
        metric: RingMetricPresentation
    ) -> String {
        guard let value = metric.value else { return "\(name), unavailable" }
        let resetValue = value.resetsAt.map {
            ", resets \(weeklyResetDateFormatter.accessibilityReset($0))"
        } ?? ""
        return "\(name), \(value.percentText) remaining\(resetValue), "
            + "\(metric.freshnessText.lowercased()), \(value.semanticLevel.text.lowercased())"
    }

}
