enum HaloAccessibility {
    static func metricValue(
        name: String,
        state: HaloMetricState<QuotaPresentation>
    ) -> String {
        switch state {
        case let .current(value):
            "\(name), \(value.remainingText) remaining, current, reset \(value.resetAccessibilityValue)"
        case let .stale(value):
            "\(name), \(value.remainingText) remaining, stale, reset \(value.resetAccessibilityValue)"
        case .unavailable:
            "\(name), unavailable"
        }
    }

    static func compactValue(_ model: HaloPresentationModel) -> String {
        var values = [metricValue(name: "Weekly quota", state: model.weekly)]
        if let fiveHour = model.fiveHour {
            values.append(metricValue(name: "Five-hour quota", state: fiveHour))
        }
        values.append("Connection, \(model.connectionState.text)")
        return values.joined(separator: "; ")
    }

    static func accountUsageValue(
        _ state: HaloMetricState<AccountUsagePresentation>
    ) -> String {
        switch state {
        case let .current(value):
            return accountUsageValue(value, status: "current")
        case let .stale(value):
            return accountUsageValue(value, status: "stale")
        case .unavailable:
            return "Account Usage, unavailable"
        }
    }

    private static func accountUsageValue(
        _ value: AccountUsagePresentation,
        status: String
    ) -> String {
        let summary = value.summaryRows.map { "\($0.label), \($0.value)" }
        let daily = value.dailyRows.map { "\($0.dateText), \($0.tokenText) tokens" }
        let details = (summary + daily).joined(separator: "; ")
        if details.isEmpty {
            return "Account Usage, \(status), no summary fields available"
        }
        return "Account Usage, \(status); \(details)"
    }
}
