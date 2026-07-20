import CoreGraphics
import Foundation

enum HaloFollowingTargetSource: Equatable, Sendable {
    case pet
    case codexWindowFallback
    case freeFloating

    var statusText: String {
        switch self {
        case .pet:
            "Target: Pet"
        case .codexWindowFallback:
            "Target: Codex Window"
        case .freeFloating:
            "Target: Free-floating"
        }
    }
}

struct PetTargetSnapshot: Equatable, Sendable {
    let generation: Int
    let frame: CGRect
    let activityGeometryHint: PetActivityGeometryHint
    let activityVerticalDelta: Double?

    init(
        generation: Int,
        frame: CGRect,
        activityGeometryHint: PetActivityGeometryHint = .none,
        activityVerticalDelta: Double? = nil
    ) {
        self.generation = generation
        self.frame = frame
        self.activityGeometryHint = activityGeometryHint
        self.activityVerticalDelta = activityVerticalDelta
    }
}

struct PetTrackedFrameSample: Equatable, Sendable {
    let generation: Int
    let frame: CGRect
}

struct PetAttachmentLayout: Equatable, Sendable {
    let referencePoint: CGPoint
    let panelFrame: CGRect
}

struct PetVisualCenterOffset: Codable, Equatable, Sendable {
    static let zero = PetVisualCenterOffset(horizontal: 0, vertical: 0)
    static let maximumMagnitude = PetRingGeometry.standard.panelDiameter

    let horizontal: Double
    let vertical: Double

    var isValid: Bool {
        horizontal.isFinite
            && vertical.isFinite
            && abs(horizontal) <= Self.maximumMagnitude
            && abs(vertical) <= Self.maximumMagnitude
    }
}

enum PetActivityGeometryHint: Equatable, Sendable {
    case none
    case above
    case below
    case ambiguous
}

struct PetActivityGeometryResolution: Equatable, Sendable {
    let hint: PetActivityGeometryHint
    let observedIdentities: Set<Int>
    let activityVerticalDelta: Double?
}

enum PetPlacementStatus: Equatable, Sendable {
    case centered
    case unavailable

    var statusText: String {
        switch self {
        case .centered:
            "Pet placement: Centered"
        case .unavailable:
            "Pet placement: Unavailable"
        }
    }
}

enum PetTargetDiscoveryState: Equatable, Sendable {
    case disabled
    case searching
    case found
    case ambiguous
    case unavailable
    case suspended

    var statusText: String {
        switch self {
        case .disabled:
            "Pet: Disabled"
        case .searching:
            "Pet: Searching"
        case .found:
            "Pet: Found"
        case .ambiguous:
            "Pet: Ambiguous"
        case .unavailable:
            "Pet: Not Found"
        case .suspended:
            "Pet: Suspended"
        }
    }
}

struct PetWindowCandidate: Equatable, Sendable {
    let identity: Int
    let frame: CGRect
    let isMinimized: Bool
    let isHidden: Bool
    let role: String?
    let subrole: String?

    var isEligibleCoreSurface: Bool {
        guard !isMinimized,
              !isHidden,
              frame.isFinite,
              frame.width > 0,
              frame.height > 0,
              role == "AXWindow",
              subrole == "AXDialog" || subrole == "AXSystemDialog"
        else {
            return false
        }
        return (0.8 ... 1.5).contains(frame.width / frame.height)
    }

    var isPreferredCoreSurface: Bool {
        isEligibleCoreSurface && subrole == "AXSystemDialog"
    }

    var isEligibleActivitySurface: Bool {
        guard !isMinimized,
              !isHidden,
              frame.isFinite,
              frame.width > 0,
              frame.height > 0,
              role == "AXWindow",
              subrole == "AXDialog" || subrole == "AXSystemDialog"
        else {
            return false
        }
        return frame.width / frame.height > 1.5
    }

    var isPreferredActivitySurface: Bool {
        isEligibleActivitySurface && subrole == "AXSystemDialog"
    }
}

enum PetWindowSelection: Equatable, Sendable {
    case unavailable
    case selected(memberIdentities: Set<Int>, frame: CGRect)
    case ambiguous
}

enum PetWindowSelector {
    static func select(from candidates: [PetWindowCandidate]) -> PetWindowSelection {
        let preferred = candidates.filter(\.isPreferredCoreSurface)
        let eligible = preferred.isEmpty
            ? candidates.filter(\.isEligibleCoreSurface)
            : preferred
        let groups = Dictionary(grouping: eligible, by: { FrameKey(frame: $0.frame) })
        guard groups.count == 1,
              let group = groups.values.first
        else {
            return groups.isEmpty ? .unavailable : .ambiguous
        }
        return .selected(
            memberIdentities: Set(group.map(\.identity)),
            frame: CGRect(
                x: group.map(\.frame.minX).reduce(0, +) / CGFloat(group.count),
                y: group.map(\.frame.minY).reduce(0, +) / CGFloat(group.count),
                width: group.map(\.frame.width).reduce(0, +) / CGFloat(group.count),
                height: group.map(\.frame.height).reduce(0, +) / CGFloat(group.count)
            )
        )
    }

    private struct FrameKey: Hashable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int

        init(frame: CGRect) {
            x = Int((frame.minX * 2).rounded())
            y = Int((frame.minY * 2).rounded())
            width = Int((frame.width * 2).rounded())
            height = Int((frame.height * 2).rounded())
        }
    }
}

enum PetTrackedFrameResolver {
    static func resolve(_ frames: [CGRect]) -> CGRect? {
        guard !frames.isEmpty,
              frames.allSatisfy({
                  $0.isFinite && $0.width > 0 && $0.height > 0
              })
        else {
            return nil
        }
        let groups = Dictionary(grouping: frames, by: FrameKey.init)
        guard groups.count == 1, let group = groups.values.first else { return nil }
        return CGRect(
            x: group.map(\.minX).reduce(0, +) / CGFloat(group.count),
            y: group.map(\.minY).reduce(0, +) / CGFloat(group.count),
            width: group.map(\.width).reduce(0, +) / CGFloat(group.count),
            height: group.map(\.height).reduce(0, +) / CGFloat(group.count)
        )
    }

    private struct FrameKey: Hashable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int

        init(_ frame: CGRect) {
            x = Int((frame.minX * 2).rounded())
            y = Int((frame.minY * 2).rounded())
            width = Int((frame.width * 2).rounded())
            height = Int((frame.height * 2).rounded())
        }
    }
}

enum PetActivityGeometryResolver {
    static func resolve(
        petFrame: CGRect,
        petMemberIdentities: Set<Int>,
        candidates: [PetWindowCandidate]
    ) -> PetActivityGeometryResolution {
        let activity = candidates.filter {
            !petMemberIdentities.contains($0.identity)
                && $0.isEligibleActivitySurface
                && horizontalOverlap($0.frame, petFrame)
        }
        let identities = Set(activity.map(\.identity))
        let preferred = activity.filter(\.isPreferredActivitySurface)
        let orientedActivity = preferred.isEmpty
            ? activity.filter { $0.subrole == "AXDialog" }
            : preferred
        guard orientedActivity.count == 1, let dialog = orientedActivity.first else {
            return PetActivityGeometryResolution(
                hint: activity.isEmpty ? .none : .ambiguous,
                observedIdentities: identities,
                activityVerticalDelta: nil
            )
        }
        let delta = dialog.frame.midY - petFrame.midY
        guard abs(delta) > 1 else {
            return PetActivityGeometryResolution(
                hint: .ambiguous,
                observedIdentities: identities,
                activityVerticalDelta: nil
            )
        }
        return PetActivityGeometryResolution(
            hint: delta < 0 ? .above : .below,
            observedIdentities: identities,
            activityVerticalDelta: -delta
        )
    }

    private static func horizontalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        min(lhs.maxX, rhs.maxX) > max(lhs.minX, rhs.minX)
    }
}

enum PetAttachmentLayoutPolicy {
    static let petAttachmentSize = PetRingGeometry.standard.panelSize

    static func centeredLayout(
        petFrame: CGRect,
        panelSize: CGSize,
        visualCenterOffset: PetVisualCenterOffset = .zero
    ) -> PetAttachmentLayout? {
        guard petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0,
              panelSize.isFinite,
              panelSize.width > 0,
              panelSize.height > 0,
              visualCenterOffset.isValid
        else {
            return nil
        }
        let visualCenter = CGPoint(
            x: petFrame.midX + visualCenterOffset.horizontal,
            y: petFrame.midY + visualCenterOffset.vertical
        )
        let panelFrame = CGRect(
            x: visualCenter.x - panelSize.width / 2,
            y: visualCenter.y - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        return PetAttachmentLayout(
            referencePoint: HaloPlacementGeometry.referencePoint(for: panelFrame),
            panelFrame: panelFrame
        )
    }

    static func visualCenterOffset(
        panelReferencePoint: CGPoint,
        petFrame: CGRect,
        panelSize: CGSize
    ) -> PetVisualCenterOffset? {
        guard panelReferencePoint.isFinite,
              petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0,
              panelSize.isFinite,
              panelSize.width > 0,
              panelSize.height > 0
        else {
            return nil
        }
        let offset = PetVisualCenterOffset(
            horizontal: panelReferencePoint.x - panelSize.width / 2 - petFrame.midX,
            vertical: panelReferencePoint.y - panelSize.height / 2 - petFrame.midY
        )
        return offset.isValid ? offset : nil
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
