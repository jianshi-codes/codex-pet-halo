import Foundation

enum PetRingSemanticLevel: String, Equatable, Sendable {
    case healthy
    case warning
    case critical

    var text: String {
        rawValue.capitalized
    }
}

struct RingMetricValue: Equatable, Sendable {
    let remainingPercent: Double
    let displayedPercent: Int
    let semanticLevel: PetRingSemanticLevel

    var progress: Double {
        min(max(remainingPercent / 100, 0), 1)
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
    let peakDailyTokenCount: UInt64
    let peakTokenText: String
    let consumptionRatio: Double
    let semanticLevel: PetRingSemanticLevel

    var progress: Double {
        min(max(consumptionRatio, 0), 1)
    }

    var percentOfPeakText: String {
        "\(Int((consumptionRatio * 100).rounded(.toNearestOrAwayFromZero)))%"
    }
}

enum TodayTokenPresentation: Equatable, Sendable {
    case current(TodayTokenValue)
    case stale(TodayTokenValue)

    var value: TodayTokenValue {
        switch self {
        case let .current(value), let .stale(value):
            value
        }
    }

    var freshnessText: String {
        switch self {
        case .current:
            "Current"
        case .stale:
            "Stale"
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
        accessibilityValue: "Weekly quota, unavailable"
    )
}
