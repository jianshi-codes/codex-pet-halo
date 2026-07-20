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
}

struct PetAttachmentLayout: Equatable, Sendable {
    let referencePoint: CGPoint
    let panelFrame: CGRect
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
              subrole == "AXDialog"
        else {
            return false
        }
        return (0.8 ... 1.5).contains(frame.width / frame.height)
    }
}

enum PetWindowSelection: Equatable, Sendable {
    case unavailable
    case selected(memberIdentities: Set<Int>, frame: CGRect)
    case ambiguous
}

enum PetWindowSelector {
    static func select(from candidates: [PetWindowCandidate]) -> PetWindowSelection {
        let eligible = candidates.filter(\.isEligibleCoreSurface)
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

enum PetAttachmentLayoutPolicy {
    static func centeredLayout(
        petFrame: CGRect,
        panelSize: CGSize
    ) -> PetAttachmentLayout? {
        guard petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0,
              panelSize.isFinite,
              panelSize.width > 0,
              panelSize.height > 0
        else {
            return nil
        }
        let panelFrame = CGRect(
            x: petFrame.midX - panelSize.width / 2,
            y: petFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        return PetAttachmentLayout(
            referencePoint: HaloPlacementGeometry.referencePoint(for: panelFrame),
            panelFrame: panelFrame
        )
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
