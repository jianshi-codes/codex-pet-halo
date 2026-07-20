import Foundation

enum RemainingLevel: String, Equatable, Sendable {
    case normal
    case low
    case critical

    init(remainingPercent: Double) {
        if remainingPercent <= 10 {
            self = .critical
        } else if remainingPercent <= 25 {
            self = .low
        } else {
            self = .normal
        }
    }

    var text: String {
        rawValue.capitalized
    }
}

struct RingMetricValue: Equatable, Sendable {
    let remainingPercent: Double
    let displayedPercent: Int
    let remainingLevel: RemainingLevel

    var progress: Double {
        remainingPercent / 100
    }

    var percentText: String {
        "\(displayedPercent)%"
    }
}

enum RingMetricPresentation: Equatable, Sendable {
    case current(RingMetricValue)
    case stale(RingMetricValue)
    case unavailable

    var value: RingMetricValue? {
        switch self {
        case let .current(value), let .stale(value):
            value
        case .unavailable:
            nil
        }
    }

    var freshnessText: String {
        switch self {
        case .current:
            "Current"
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }

    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

struct TodayTokenValue: Equatable, Sendable {
    let tokenCount: UInt64
    let tokenText: String
}

enum TodayTokenPresentation: Equatable, Sendable {
    case current(TodayTokenValue)
    case stale(TodayTokenValue)
    case unavailable

    var value: TodayTokenValue? {
        switch self {
        case let .current(value), let .stale(value):
            value
        case .unavailable:
            nil
        }
    }

    var freshnessText: String {
        switch self {
        case .current:
            "Current"
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }

    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

struct PetRingPresentationModel: Equatable, Sendable {
    let weekly: RingMetricPresentation
    let fiveHour: RingMetricPresentation?
    let todayTokens: TodayTokenPresentation?
    let accessibilityValue: String

    static let starting = PetRingPresentationModel(
        weekly: .unavailable,
        fiveHour: nil,
        todayTokens: nil,
        accessibilityValue: "Weekly quota, unavailable; Today tokens, unavailable"
    )
}
