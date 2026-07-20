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

struct PetEnvironmentSnapshot: Equatable, Sendable {
    let generation: Int
    let petFrame: CGRect
    let activityFrame: CGRect?

    init(generation: Int, petFrame: CGRect, activityFrame: CGRect? = nil) {
        self.generation = generation
        self.petFrame = petFrame
        self.activityFrame = activityFrame
    }
}

enum PetPlacementMode: Equatable, Sendable {
    case automatic
    case manual
}

enum PetAttachmentSide: Equatable, Sendable {
    case above
    case below
}

struct PetAttachmentLayout: Equatable, Sendable {
    let side: PetAttachmentSide
    let referencePoint: CGPoint
    let panelFrame: CGRect
}

enum PetPlacementStatus: Equatable, Sendable {
    case automatic(PetAttachmentSide)
    case manual
    case unavailable

    var statusText: String {
        switch self {
        case .automatic:
            "Pet placement: Automatic Centered"
        case .manual:
            "Pet placement: Fine-tuned"
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

enum PetActivityWindowSelector {
    static func select(
        from candidates: [PetWindowCandidate],
        excluding memberIdentities: Set<Int>,
        near petFrame: CGRect
    ) -> PetWindowCandidate? {
        guard petFrame.isFinite, petFrame.width > 0, petFrame.height > 0 else { return nil }
        let proximity = max(max(petFrame.width, petFrame.height) * 2, 240)
        let nearbyFrame = petFrame.insetBy(dx: -proximity, dy: -proximity)
        let eligible = candidates.filter { candidate in
            guard !memberIdentities.contains(candidate.identity),
                  !candidate.isMinimized,
                  !candidate.isHidden,
                  candidate.role == "AXWindow",
                  candidate.subrole == "AXDialog",
                  candidate.frame.isFinite,
                  candidate.frame.width >= max(160, petFrame.width * 0.45),
                  candidate.frame.height > 0,
                  candidate.frame.width / candidate.frame.height >= 1.8,
                  nearbyFrame.intersects(candidate.frame)
            else {
                return false
            }
            return true
        }
        return eligible.count == 1 ? eligible[0] : nil
    }
}

enum PetAttachmentLayoutPolicy {
    static func preferredSide(
        petFrame: CGRect,
        activityFrame: CGRect?,
        visibleFrame: CGRect,
        currentSide: PetAttachmentSide?
    ) -> PetAttachmentSide? {
        guard petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0,
              visibleFrame.isFinite,
              visibleFrame.width > 0,
              visibleFrame.height > 0
        else {
            return nil
        }
        if let activityFrame,
           activityFrame.isFinite,
           activityFrame.width > 0,
           activityFrame.height > 0
        {
            return activityFrame.midY < petFrame.midY ? .above : .below
        }

        let relativeCenter = (petFrame.midY - visibleFrame.minY) / visibleFrame.height
        switch currentSide {
        case .above where relativeCenter > 0.4:
            return .above
        case .below where relativeCenter < 0.6:
            return .below
        default:
            return relativeCenter >= 0.5 ? .above : .below
        }
    }

    static func centeredLayout(
        petFrame: CGRect,
        panelSize: CGSize,
        side: PetAttachmentSide
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
            side: side,
            referencePoint: HaloPlacementGeometry.referencePoint(for: panelFrame),
            panelFrame: panelFrame
        )
    }
}

struct PetRelativeAnchor: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let normalizedPetPoint: UnitPointValue
    let pointOffset: PointOffsetValue

    var isValid: Bool {
        version == Self.currentVersion
            && normalizedPetPoint.isValid
            && pointOffset.isValid
    }
}

enum PetAnchorGeometry {
    static func calibrate(referencePoint: CGPoint, petFrame: CGRect) -> PetRelativeAnchor? {
        guard referencePoint.isFinite,
              petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0
        else {
            return nil
        }
        let projected = CGPoint(
            x: min(max(referencePoint.x, petFrame.minX), petFrame.maxX),
            y: min(max(referencePoint.y, petFrame.minY), petFrame.maxY)
        )
        let anchor = PetRelativeAnchor(
            version: PetRelativeAnchor.currentVersion,
            normalizedPetPoint: UnitPointValue(
                x: (projected.x - petFrame.minX) / petFrame.width,
                y: (projected.y - petFrame.minY) / petFrame.height
            ),
            pointOffset: PointOffsetValue(
                width: referencePoint.x - projected.x,
                height: referencePoint.y - projected.y
            )
        )
        return anchor.isValid ? anchor : nil
    }

    static func referencePoint(anchor: PetRelativeAnchor, petFrame: CGRect) -> CGPoint? {
        guard anchor.isValid,
              petFrame.isFinite,
              petFrame.width > 0,
              petFrame.height > 0
        else {
            return nil
        }
        return CGPoint(
            x: petFrame.minX
                + petFrame.width * anchor.normalizedPetPoint.x
                + anchor.pointOffset.width,
            y: petFrame.minY
                + petFrame.height * anchor.normalizedPetPoint.y
                + anchor.pointOffset.height
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
