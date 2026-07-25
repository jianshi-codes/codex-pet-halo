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
    let resetsAt: Date?

    init(
        remainingPercent: Double,
        displayedPercent: Int,
        semanticLevel: PetRingSemanticLevel,
        resetsAt: Date? = nil
    ) {
        self.remainingPercent = remainingPercent
        self.displayedPercent = displayedPercent
        self.semanticLevel = semanticLevel
        self.resetsAt = resetsAt
    }

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

struct PetRingPresentationModel: Equatable, Sendable {
    let weekly: RingMetricPresentation
    let fiveHour: RingMetricPresentation?
    let accessibilityValue: String

    static let starting = PetRingPresentationModel(
        weekly: .unavailable,
        fiveHour: nil,
        accessibilityValue: "Weekly quota, unavailable"
    )
}
