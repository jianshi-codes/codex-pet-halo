import Foundation

enum PetHaloAppearance: Equatable, Sendable {
    case light
    case dark
}

struct PetRingAppearancePolicy: Equatable, Sendable {
    let capsuleBackgroundOpacity: Double
    let capsuleBorderOpacity: Double
    let trackOpacity: Double
    let connectorOpacity: Double
    let shadowOpacity: Double

    static func resolve(
        appearance: PetHaloAppearance,
        increaseContrast: Bool,
        reduceTransparency: Bool
    ) -> PetRingAppearancePolicy {
        PetRingAppearancePolicy(
            capsuleBackgroundOpacity: reduceTransparency ? 1 : (appearance == .light ? 0.94 : 0.9),
            capsuleBorderOpacity: increaseContrast ? 0.7 : 0.42,
            trackOpacity: increaseContrast ? 0.58 : 0.38,
            connectorOpacity: increaseContrast ? 0.78 : 0.58,
            shadowOpacity: reduceTransparency ? 0 : (appearance == .light ? 0.16 : 0.28)
        )
    }
}
