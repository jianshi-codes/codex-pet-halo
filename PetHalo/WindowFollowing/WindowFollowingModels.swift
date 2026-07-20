import CoreGraphics
import Foundation

enum WindowFollowingPermissionState: Equatable, Sendable {
    case unknown
    case notGranted
    case granted
}

enum WindowFollowingUnavailableReason: Equatable, Sendable {
    case permissionRequired
    case codexUnavailable
    case processAmbiguous
    case windowUnavailable
    case windowAmbiguous
    case observerFailed
    case invalidPlacement
}

enum WindowFollowingState: Equatable, Sendable {
    case disabled
    case permissionRequired
    case searching
    case calibrationRequired
    case calibrating
    case following
    case suspended(WindowFollowingUnavailableReason)
    case unavailable(WindowFollowingUnavailableReason)

    var statusText: String {
        switch self {
        case .disabled:
            "Following: Off"
        case .permissionRequired:
            "Following: Needs Permission"
        case .searching:
            "Following: Searching"
        case .calibrationRequired, .calibrating:
            "Following: Calibration Required"
        case .following:
            "Following: On"
        case .suspended:
            "Following: Suspended"
        case let .unavailable(reason):
            switch reason {
            case .codexUnavailable:
                "Following: Codex Unavailable"
            case .processAmbiguous, .windowAmbiguous:
                "Following: Target Ambiguous"
            case .permissionRequired:
                "Following: Needs Permission"
            case .windowUnavailable, .observerFailed, .invalidPlacement:
                "Following: Unavailable"
            }
        }
    }
}

struct CodexApplicationCandidate: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let isActive: Bool
}

enum CodexApplicationSelection: Equatable, Sendable {
    case unavailable
    case selected(processIdentifier: Int32)
    case ambiguous
}

enum CodexApplicationSelector {
    static let bundleIdentifier = "com.openai.codex"

    static func select(from candidates: [CodexApplicationCandidate]) -> CodexApplicationSelection {
        let exact = candidates.filter { $0.bundleIdentifier == bundleIdentifier }
        if exact.isEmpty {
            return .unavailable
        }
        if exact.count == 1, let candidate = exact.first {
            return .selected(processIdentifier: candidate.processIdentifier)
        }
        let active = exact.filter(\.isActive)
        if active.count == 1, let candidate = active.first {
            return .selected(processIdentifier: candidate.processIdentifier)
        }
        return .ambiguous
    }
}

struct CodexWindowCandidate: Equatable, Sendable {
    let identity: Int
    let frame: CGRect
    let isFocused: Bool
    let isMain: Bool
    let isMinimized: Bool
    let isVisible: Bool
    let role: String?
    let subrole: String?

    var isEligible: Bool {
        guard isVisible,
              !isMinimized,
              frame.width > 0,
              frame.height > 0,
              role == "AXWindow"
        else {
            return false
        }
        return subrole == nil || subrole == "AXStandardWindow"
    }
}

enum CodexWindowSelection: Equatable, Sendable {
    case unavailable
    case selected(identity: Int)
    case ambiguous
}

enum CodexWindowSelector {
    static func select(from candidates: [CodexWindowCandidate]) -> CodexWindowSelection {
        let eligible = candidates.filter(\.isEligible)
        let focused = eligible.filter(\.isFocused)
        if focused.count == 1, let candidate = focused.first {
            return .selected(identity: candidate.identity)
        }
        if focused.count > 1 {
            return .ambiguous
        }
        let main = eligible.filter(\.isMain)
        if main.count == 1, let candidate = main.first {
            return .selected(identity: candidate.identity)
        }
        if main.count > 1 {
            return .ambiguous
        }
        if eligible.count == 1, let candidate = eligible.first {
            return .selected(identity: candidate.identity)
        }
        return eligible.isEmpty ? .unavailable : .ambiguous
    }
}

struct AXCoordinateConverter: Equatable, Sendable {
    let primaryDisplayFrame: CGRect

    func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect? {
        guard frame.isFinite, primaryDisplayFrame.isFinite else { return nil }
        return CGRect(
            x: frame.minX,
            y: primaryDisplayFrame.maxY - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }
}

struct UnitPointValue: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    var isValid: Bool {
        x.isFinite && y.isFinite && (0 ... 1).contains(x) && (0 ... 1).contains(y)
    }
}

struct PointOffsetValue: Codable, Equatable, Sendable {
    let width: Double
    let height: Double

    var isValid: Bool {
        width.isFinite
            && height.isFinite
            && abs(width) <= HaloWindowAnchor.maximumReasonableOffset
            && abs(height) <= HaloWindowAnchor.maximumReasonableOffset
    }
}

struct HaloWindowAnchor: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let maximumReasonableOffset = 10_000.0

    let version: Int
    let normalizedWindowPoint: UnitPointValue
    let pointOffset: PointOffsetValue

    var isValid: Bool {
        version == Self.currentVersion
            && normalizedWindowPoint.isValid
            && pointOffset.isValid
    }
}

enum HaloAnchorGeometry {
    static func calibrate(referencePoint: CGPoint, windowFrame: CGRect) -> HaloWindowAnchor? {
        guard referencePoint.isFinite,
              windowFrame.isFinite,
              windowFrame.width > 0,
              windowFrame.height > 0
        else {
            return nil
        }
        let projected = CGPoint(
            x: min(max(referencePoint.x, windowFrame.minX), windowFrame.maxX),
            y: min(max(referencePoint.y, windowFrame.minY), windowFrame.maxY)
        )
        let anchor = HaloWindowAnchor(
            version: HaloWindowAnchor.currentVersion,
            normalizedWindowPoint: UnitPointValue(
                x: (projected.x - windowFrame.minX) / windowFrame.width,
                y: (projected.y - windowFrame.minY) / windowFrame.height
            ),
            pointOffset: PointOffsetValue(
                width: referencePoint.x - projected.x,
                height: referencePoint.y - projected.y
            )
        )
        return anchor.isValid ? anchor : nil
    }

    static func referencePoint(anchor: HaloWindowAnchor, windowFrame: CGRect) -> CGPoint? {
        guard anchor.isValid,
              windowFrame.isFinite,
              windowFrame.width > 0,
              windowFrame.height > 0
        else {
            return nil
        }
        return CGPoint(
            x: windowFrame.minX
                + windowFrame.width * anchor.normalizedWindowPoint.x
                + anchor.pointOffset.width,
            y: windowFrame.minY
                + windowFrame.height * anchor.normalizedWindowPoint.y
                + anchor.pointOffset.height
        )
    }
}

struct ScreenGeometry: Equatable, Sendable {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum HaloPlacementGeometry {
    static func referencePoint(for frame: CGRect) -> CGPoint {
        CGPoint(x: frame.maxX, y: frame.maxY)
    }

    static func frame(referencePoint: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: referencePoint.x - size.width,
            y: referencePoint.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func containedFrame(
        referencePoint: CGPoint,
        size: CGSize,
        screens: [ScreenGeometry]
    ) -> CGRect? {
        guard referencePoint.isFinite,
              size.isFinite,
              size.width > 0,
              size.height > 0,
              let screen = selectedScreen(for: referencePoint, screens: screens)
        else {
            return nil
        }
        let proposed = frame(referencePoint: referencePoint, size: size)
        let visible = screen.visibleFrame
        let width = min(proposed.width, visible.width)
        let height = min(proposed.height, visible.height)
        let maximumX = max(visible.minX, visible.maxX - width)
        let maximumY = max(visible.minY, visible.maxY - height)
        return CGRect(
            x: min(max(proposed.minX, visible.minX), maximumX),
            y: min(max(proposed.minY, visible.minY), maximumY),
            width: width,
            height: height
        )
    }

    static func selectedScreen(
        for point: CGPoint,
        screens: [ScreenGeometry]
    ) -> ScreenGeometry? {
        let valid = screens.filter { $0.frame.isFinite && $0.visibleFrame.isFinite }
        if let containing = valid.first(where: { $0.frame.contains(point) }) {
            return containing
        }
        return valid.min { squaredDistance(from: point, to: $0.visibleFrame)
            < squaredDistance(from: point, to: $1.visibleFrame) }
    }

    private static func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - x
        let dy = point.y - y
        return dx * dx + dy * dy
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.isFinite && size.isFinite
    }
}

private extension CGPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

private extension CGSize {
    var isFinite: Bool {
        width.isFinite && height.isFinite
    }
}
