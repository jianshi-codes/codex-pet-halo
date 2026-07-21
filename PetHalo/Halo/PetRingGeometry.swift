import CoreGraphics
import Foundation

enum PetRingOrientation: Equatable, Sendable {
    case openingTop
    case openingBottom

    static let fixedDefault: PetRingOrientation = .openingTop
}

enum PetRingLabelSide: Equatable, Sendable {
    case left
    case right
}

extension PetRingOrientation {
    var preferredLabelSide: PetRingLabelSide {
        switch self {
        case .openingTop:
            .right
        case .openingBottom:
            .left
        }
    }
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

struct PetRingConnectorSegment: Equatable, Sendable {
    let ringPoint: CGPoint
    let capsulePoint: CGPoint
}

struct PetRingGeometry: Equatable, Sendable {
    let outerRadius: Double
    let ringSpacing: Double
    let lineWidth: Double
    let panelWidth: Double
    let panelDiameter: Double

    var panelSize: CGSize {
        CGSize(width: panelWidth, height: panelDiameter)
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
        side: PetRingLabelSide,
        visibleMetrics: [PetRingMetricKind]
    ) -> CGPoint {
        let size = labelSize(for: metric)
        let center = ringCenter(in: panelSize)
        let connectorGap = 10.0
        let rightStackLeadingEdge = center.x + outerRadius + connectorGap
        let leftStackTrailingEdge = center.x - outerRadius - connectorGap
        let x: Double
        switch side {
        case .right:
            x = rightStackLeadingEdge + size.width / 2
        case .left:
            x = leftStackTrailingEdge - size.width / 2
        }
        let metrics = visibleMetrics.isEmpty ? [metric] : visibleMetrics
        let index = metrics.firstIndex(of: metric) ?? 0
        let stackSpacing = 30.0
        let y = center.y
            + (Double(metrics.count - 1) / 2 - Double(index)) * stackSpacing
        return CGPoint(
            x: x,
            y: y
        )
    }

    func labelSize(for metric: PetRingMetricKind) -> CGSize {
        switch metric {
        case .weekly:
            CGSize(width: 106, height: 24)
        case .fiveHour:
            CGSize(width: 72, height: 24)
        case .today:
            CGSize(width: 106, height: 24)
        }
    }

    func labelFrame(
        for metric: PetRingMetricKind,
        side: PetRingLabelSide,
        visibleMetrics: [PetRingMetricKind]
    ) -> CGRect {
        let position = labelPosition(
            for: metric,
            side: side,
            visibleMetrics: visibleMetrics
        )
        let size = labelSize(for: metric)
        return CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    func connectorSegment(
        for metric: PetRingMetricKind,
        side: PetRingLabelSide,
        visibleMetrics: [PetRingMetricKind]
    ) -> PetRingConnectorSegment {
        let frame = labelFrame(
            for: metric,
            side: side,
            visibleMetrics: visibleMetrics
        )
        let center = ringCenter(in: panelSize)
        let radius = radius(for: metric)
        let ringY = frame.midY
        let verticalDistance = ringY - center.y
        let horizontalDistance = sqrt(max(radius * radius - verticalDistance * verticalDistance, 0))
        let ringX: Double
        let capsuleX: Double
        switch side {
        case .right:
            ringX = center.x + horizontalDistance
            capsuleX = frame.minX
        case .left:
            ringX = center.x - horizontalDistance
            capsuleX = frame.maxX
        }
        return PetRingConnectorSegment(
            ringPoint: CGPoint(x: ringX, y: ringY),
            capsulePoint: CGPoint(x: capsuleX, y: ringY)
        )
    }

    static let standard = PetRingGeometry(
        outerRadius: 104,
        ringSpacing: 10,
        lineWidth: 6,
        panelWidth: 448,
        panelDiameter: 252
    )
}

enum PetRingLabelPlacementPolicy {
    static let hysteresisInset = 8.0

    static func side(
        panelFrame: CGRect,
        visibleFrame: CGRect,
        visibleMetrics: [PetRingMetricKind],
        preferredSide: PetRingLabelSide,
        currentSide: PetRingLabelSide?,
        geometry: PetRingGeometry = .standard
    ) -> PetRingLabelSide {
        let leftFrame = globalLabelFrame(
            side: .left,
            panelFrame: panelFrame,
            visibleMetrics: visibleMetrics,
            geometry: geometry
        )
        let rightFrame = globalLabelFrame(
            side: .right,
            panelFrame: panelFrame,
            visibleMetrics: visibleMetrics,
            geometry: geometry
        )
        let leftFits = visibleFrame.contains(leftFrame)
        let rightFits = visibleFrame.contains(rightFrame)

        if leftFits != rightFits {
            return leftFits ? .left : .right
        }
        if leftFits, rightFits,
           let currentSide,
           currentSide != preferredSide
        {
            let preferredFrame = preferredSide == .left ? leftFrame : rightFrame
            let settledFrame = visibleFrame.insetBy(
                dx: hysteresisInset,
                dy: 0
            )
            return settledFrame.contains(preferredFrame) ? preferredSide : currentSide
        }
        if leftFits, rightFits {
            return preferredSide
        }
        return overflow(of: leftFrame, outside: visibleFrame)
            <= overflow(of: rightFrame, outside: visibleFrame) ? .left : .right
    }

    static func globalLabelFrame(
        side: PetRingLabelSide,
        panelFrame: CGRect,
        visibleMetrics: [PetRingMetricKind],
        geometry: PetRingGeometry = .standard
    ) -> CGRect {
        visibleMetrics.reduce(CGRect.null) { result, metric in
            let local = geometry.labelFrame(
                for: metric,
                side: side,
                visibleMetrics: visibleMetrics
            )
            return result.union(local.offsetBy(dx: panelFrame.minX, dy: panelFrame.minY))
        }
    }

    private static func overflow(of frame: CGRect, outside visibleFrame: CGRect) -> Double {
        max(visibleFrame.minX - frame.minX, 0)
            + max(frame.maxX - visibleFrame.maxX, 0)
    }
}
