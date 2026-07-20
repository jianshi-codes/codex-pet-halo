import Foundation

struct PetRingIdentityColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

enum PetRingPresentationPolicy {
    static func identityColor(for metric: PetRingMetricKind) -> PetRingIdentityColor {
        switch metric {
        case .weekly:
            PetRingIdentityColor(red: 0x58, green: 0x65, blue: 0xF2)
        case .fiveHour:
            PetRingIdentityColor(red: 0x00, green: 0xB8, blue: 0xD9)
        case .today:
            PetRingIdentityColor(red: 0xA8, green: 0x55, blue: 0xF7)
        }
    }

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
