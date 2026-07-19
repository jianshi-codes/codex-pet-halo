import Foundation
import PetHaloCore

enum HaloMetricState<Value: Equatable & Sendable>: Equatable, Sendable {
    case current(Value)
    case stale(Value)
    case unavailable

    var value: Value? {
        switch self {
        case let .current(value), let .stale(value):
            value
        case .unavailable:
            nil
        }
    }

    var statusText: String {
        switch self {
        case .current:
            "Current"
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }
}

enum HaloConnectionPresentation: Equatable, Sendable {
    case starting
    case connected
    case unavailable

    var text: String {
        switch self {
        case .starting:
            "Starting"
        case .connected:
            "Connected"
        case .unavailable:
            "Unavailable"
        }
    }
}

struct QuotaPresentation: Equatable, Sendable {
    let remainingPercent: Double
    let displayedPercent: Int
    let resetText: String
    let resetAccessibilityValue: String

    var remainingText: String {
        "\(displayedPercent)%"
    }

    var gaugeFraction: Double {
        remainingPercent / 100
    }
}

struct AccountUsageRowPresentation: Equatable, Identifiable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}

struct DailyUsagePresentation: Equatable, Identifiable, Sendable {
    let date: Date
    let dateText: String
    let tokenText: String

    var id: Date { date }
}

struct AccountUsagePresentation: Equatable, Sendable {
    let summaryRows: [AccountUsageRowPresentation]
    let dailyRows: [DailyUsagePresentation]
}

struct HaloPresentationModel: Equatable, Sendable {
    let connectionState: HaloConnectionPresentation
    let weekly: HaloMetricState<QuotaPresentation>
    let fiveHour: HaloMetricState<QuotaPresentation>?
    let accountUsage: HaloMetricState<AccountUsagePresentation>
    let aggregateFreshness: DataFreshness

    static let starting = HaloPresentationModel(
        connectionState: .starting,
        weekly: .unavailable,
        fiveHour: nil,
        accountUsage: .unavailable,
        aggregateFreshness: .unavailable
    )
}
