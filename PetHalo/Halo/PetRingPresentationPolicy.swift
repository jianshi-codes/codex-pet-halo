import Foundation

struct PetRingIdentityColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    func contrastRatio(against other: PetRingIdentityColor) -> Double {
        let brighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (brighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: Double {
        func component(_ value: UInt8) -> Double {
            let normalized = Double(value) / 255
            return normalized <= 0.04045
                ? normalized / 12.92
                : pow((normalized + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * component(red)
            + 0.7152 * component(green)
            + 0.0722 * component(blue)
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

    static func identityTextColor(
        for metric: PetRingMetricKind,
        appearance: PetHaloAppearance
    ) -> PetRingIdentityColor {
        switch (metric, appearance) {
        case (.weekly, .light):
            PetRingIdentityColor(red: 0x44, green: 0x52, blue: 0xD6)
        case (.fiveHour, .light):
            PetRingIdentityColor(red: 0x00, green: 0x67, blue: 0x7A)
        case (.today, .light):
            PetRingIdentityColor(red: 0x7E, green: 0x22, blue: 0xCE)
        case (.weekly, .dark):
            PetRingIdentityColor(red: 0x8B, green: 0x94, blue: 0xFF)
        case (.fiveHour, .dark):
            identityColor(for: .fiveHour)
        case (.today, .dark):
            PetRingIdentityColor(red: 0xD1, green: 0xA6, blue: 0xFF)
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
