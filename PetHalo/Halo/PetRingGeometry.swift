import CoreGraphics
import Foundation

enum PetRingOrientation: Equatable, Sendable {
    case openingTop
    case openingBottom

    static let fixedDefault: PetRingOrientation = .openingTop
}

#if DEBUG
enum PetRingOrientationPreview: String, CaseIterable, Equatable, Sendable {
    case auto
    case forceGapAbove
    case forceGapBelow

    var label: String {
        switch self {
        case .auto:
            "Auto"
        case .forceGapAbove:
            "Force Gap Above"
        case .forceGapBelow:
            "Force Gap Below"
        }
    }

    func orientation(auto: PetRingOrientation) -> PetRingOrientation {
        switch self {
        case .auto:
            auto
        case .forceGapAbove:
            .openingTop
        case .forceGapBelow:
            .openingBottom
        }
    }

    static func from(arguments: [String]) -> PetRingOrientationPreview {
        guard let value = arguments.first(where: {
            $0.hasPrefix("--pet-ring-orientation=")
        })?.split(separator: "=", maxSplits: 1).last else {
            return .auto
        }
        switch value {
        case "gap-above":
            return .forceGapAbove
        case "gap-below":
            return .forceGapBelow
        default:
            return .auto
        }
    }
}
#endif

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
        let angle = labelAngleDegrees(for: metric, orientation: orientation)
            * .pi / 180
        let distance = radius(for: metric) + 8
        let center = ringCenter(in: panelSize)
        return CGPoint(
            x: center.x + distance * cos(angle),
            y: center.y + distance * sin(angle)
        )
    }

    func labelAngleDegrees(
        for metric: PetRingMetricKind,
        orientation: PetRingOrientation
    ) -> Double {
        let openingTopAngle: Double
        switch metric {
        case .weekly:
            openingTopAngle = 135
        case .fiveHour:
            openingTopAngle = 90
        case .today:
            openingTopAngle = 45
        }
        switch orientation {
        case .openingTop:
            return openingTopAngle
        case .openingBottom:
            return 360 - openingTopAngle
        }
    }

    func labelSize(for metric: PetRingMetricKind) -> CGSize {
        switch metric {
        case .weekly:
            CGSize(width: 52, height: 16)
        case .fiveHour:
            CGSize(width: 60, height: 16)
        case .today:
            CGSize(width: 108, height: 16)
        }
    }

    func labelFrame(
        for metric: PetRingMetricKind,
        orientation: PetRingOrientation
    ) -> CGRect {
        let position = labelPosition(for: metric, orientation: orientation)
        let size = labelSize(for: metric)
        return CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static let standard = PetRingGeometry(
        outerRadius: 104,
        ringSpacing: 10,
        lineWidth: 6,
        panelDiameter: 252
    )
}
