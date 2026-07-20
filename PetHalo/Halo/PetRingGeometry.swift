import CoreGraphics
import Foundation

enum PetRingOrientation: Equatable, Sendable {
    case openingTop
    case openingBottom

    static let fixedDefault: PetRingOrientation = .openingTop
}

enum PetRingMetricKind: Equatable, Sendable {
    case weekly
    case fiveHour
    case today
}

struct PetRingArcAngles: Equatable, Sendable {
    let startAngleDegrees: Double
    let sweepAngleDegrees: Double
}

struct PetRingGeometry: Equatable, Sendable {
    let outerRadius: Double
    let ringSpacing: Double
    let lineWidth: Double
    let panelDiameter: Double

    var panelSize: CGSize {
        CGSize(width: panelDiameter, height: panelDiameter)
    }

    var transparentCenterDiameter: Double {
        2 * (radius(for: .today) - lineWidth / 2)
    }

    func radius(for metric: PetRingMetricKind) -> Double {
        switch metric {
        case .weekly:
            outerRadius
        case .fiveHour:
            outerRadius - ringSpacing
        case .today:
            outerRadius - 2 * ringSpacing
        }
    }

    func angles(for orientation: PetRingOrientation) -> PetRingArcAngles {
        switch orientation {
        case .openingTop:
            PetRingArcAngles(startAngleDegrees: -40, sweepAngleDegrees: 260)
        case .openingBottom:
            PetRingArcAngles(startAngleDegrees: 140, sweepAngleDegrees: 260)
        }
    }

    func ringCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func labelPosition(
        for metric: PetRingMetricKind,
        orientation: PetRingOrientation
    ) -> CGPoint {
        let y: Double
        switch orientation {
        case .openingTop:
            y = panelDiameter - 12
        case .openingBottom:
            y = 12
        }
        let x: Double
        switch metric {
        case .fiveHour:
            x = 82
        case .weekly:
            x = 32
        case .today:
            x = panelDiameter - 67
        }
        return CGPoint(x: x, y: y)
    }

    static let standard = PetRingGeometry(
        outerRadius: 104,
        ringSpacing: 10,
        lineWidth: 6,
        panelDiameter: 252
    )
}
