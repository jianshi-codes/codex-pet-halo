import Foundation

enum PetRingPresentationPolicy {
    static func remainingLevel(for remainingPercent: Double) -> PetRingSemanticLevel {
        if remainingPercent >= 50 {
            return .healthy
        }
        if remainingPercent >= 20 {
            return .warning
        }
        return .critical
    }

    static func todayLevel(for consumptionRatio: Double) -> PetRingSemanticLevel {
        if consumptionRatio <= 0.5 {
            return .healthy
        }
        if consumptionRatio <= 0.8 {
            return .warning
        }
        return .critical
    }
}
