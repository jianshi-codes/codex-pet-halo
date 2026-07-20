import CoreGraphics
import Foundation

struct PetRingGeometry: Equatable, Sendable {
    let startAngleDegrees: Double
    let sweepAngleDegrees: Double
    let radius: Double
    let primaryLineWidth: Double
    let secondaryLineWidth: Double
    let panelDiameter: Double

    var panelSize: CGSize {
        CGSize(width: panelDiameter, height: panelDiameter)
    }

    var transparentCenterDiameter: Double {
        2 * (radius - primaryLineWidth / 2)
    }

    static let standard = PetRingGeometry(
        startAngleDegrees: -90,
        sweepAngleDegrees: 360,
        radius: 84,
        primaryLineWidth: 10,
        secondaryLineWidth: 5,
        panelDiameter: 208
    )
}
