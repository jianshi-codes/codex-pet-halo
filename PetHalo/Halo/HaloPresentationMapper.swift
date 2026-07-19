import Foundation
import PetHaloCore

struct HaloPresentationMapper {
    private let now: @Sendable () -> Date
    private let locale: Locale
    private let timeZone: TimeZone

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.now = now
        self.locale = locale
        self.timeZone = timeZone
    }

    func map(_ state: CodexUsageState) -> HaloPresentationModel {
        HaloPresentationModel(
            connectionState: connectionPresentation(state.connection),
            weekly: quotaState(
                capability: state.capabilities.generalWeekly,
                freshness: state.componentFreshness.rateLimits
            ),
            fiveHour: fiveHourState(
                capability: state.capabilities.generalFiveHour,
                freshness: state.componentFreshness.rateLimits
            ),
            accountUsage: accountUsageState(
                capability: state.capabilities.accountUsage,
                freshness: state.componentFreshness.accountUsage
            ),
            aggregateFreshness: state.freshness
        )
    }

    private func connectionPresentation(_ state: BridgeConnectionState) -> HaloConnectionPresentation {
        switch state {
        case .connected:
            .connected
        case .starting, .reconnecting:
            .starting
        case .stopped, .unavailable:
            .unavailable
        }
    }

    private func fiveHourState(
        capability: Capability<QuotaWindow>,
        freshness: DataFreshness
    ) -> HaloMetricState<QuotaPresentation>? {
        guard case .available = capability else { return nil }
        return quotaState(capability: capability, freshness: freshness)
    }

    private func quotaState(
        capability: Capability<QuotaWindow>,
        freshness: DataFreshness
    ) -> HaloMetricState<QuotaPresentation> {
        guard case let .available(window) = capability else { return .unavailable }
        let presentation = quotaPresentation(window)
        switch freshness {
        case .current:
            return .current(presentation)
        case .stale:
            return .stale(presentation)
        case .unavailable:
            return .unavailable
        }
    }

    private func quotaPresentation(_ window: QuotaWindow) -> QuotaPresentation {
        QuotaPresentation(
            remainingPercent: window.remainingPercent,
            displayedPercent: Int(window.remainingPercent.rounded(.toNearestOrAwayFromZero)),
            resetText: visibleResetText(window.resetsAt),
            resetAccessibilityValue: absoluteResetText(window.resetsAt)
        )
    }

    private func visibleResetText(_ resetDate: Date?) -> String {
        guard let resetDate else { return "Reset unavailable" }
        let currentDate = now()
        guard resetDate > currentDate else { return "Reset due" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return "Resets \(formatter.localizedString(for: resetDate, relativeTo: currentDate))"
    }

    private func absoluteResetText(_ resetDate: Date?) -> String {
        guard let resetDate else { return "Unavailable" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: resetDate)
    }

    private func accountUsageState(
        capability: Capability<AccountUsage>,
        freshness: DataFreshness
    ) -> HaloMetricState<AccountUsagePresentation> {
        guard case let .available(usage) = capability else { return .unavailable }
        let presentation = accountUsagePresentation(usage)
        switch freshness {
        case .current:
            return .current(presentation)
        case .stale:
            return .stale(presentation)
        case .unavailable:
            return .unavailable
        }
    }

    private func accountUsagePresentation(_ usage: AccountUsage) -> AccountUsagePresentation {
        let summary = usage.summary
        var rows: [AccountUsageRowPresentation] = []
        appendNumber(summary.lifetimeTokenCount, label: "Lifetime tokens", to: &rows)
        appendNumber(summary.peakDailyTokenCount, label: "Peak daily tokens", to: &rows)
        if let seconds = summary.longestRunningTurnSeconds {
            rows.append(
                AccountUsageRowPresentation(
                    label: "Longest turn",
                    value: durationText(seconds)
                )
            )
        }
        appendNumber(summary.currentStreakDays, label: "Current streak (days)", to: &rows)
        appendNumber(summary.longestStreakDays, label: "Longest streak (days)", to: &rows)

        let dailyRows = (usage.dailyBuckets ?? [])
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { bucket in
                DailyUsagePresentation(
                    date: bucket.date,
                    dateText: dateText(bucket.date),
                    tokenText: numberText(bucket.tokenCount)
                )
            }
        return AccountUsagePresentation(summaryRows: rows, dailyRows: Array(dailyRows))
    }

    private func appendNumber(
        _ value: UInt64?,
        label: String,
        to rows: inout [AccountUsageRowPresentation]
    ) {
        guard let value else { return }
        rows.append(AccountUsageRowPresentation(label: label, value: numberText(value)))
    }

    private func numberText(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func durationText(_ seconds: UInt64) -> String {
        if seconds < 60 {
            return "\(numberText(seconds)) sec"
        }
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0, minutes > 0 {
            return "\(numberText(hours)) hr \(numberText(minutes)) min"
        }
        if hours > 0 {
            return "\(numberText(hours)) hr"
        }
        return "\(numberText(minutes)) min"
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
