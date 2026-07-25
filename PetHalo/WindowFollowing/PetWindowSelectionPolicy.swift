import CoreGraphics
import Foundation

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
              frame.hasFiniteComponents,
              frame.width > 0,
              frame.height > 0,
              role == "AXWindow",
              subrole == "AXDialog" || subrole == "AXSystemDialog"
        else {
            return false
        }
        return (0.8 ... 1.5).contains(frame.width / frame.height)
    }

    var isSystemDialogCoreSurface: Bool {
        isEligibleCoreSurface && subrole == "AXSystemDialog"
    }
}

private extension CGRect {
    var hasFiniteComponents: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
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
        guard !groups.isEmpty else { return .unavailable }

        // Current Codex exposes the live Pet core as the largest balanced SystemDialog.
        // Smaller balanced SystemDialogs are controls, while coincident Dialogs may retain
        // stale geometry across Tuck Away and Wake.
        let systemDialogGroups = groups.values.filter {
            $0.contains(where: \.isSystemDialogCoreSurface)
        }
        if !systemDialogGroups.isEmpty {
            let largestArea = systemDialogGroups.map(areaKey).max()
            let largest = systemDialogGroups.filter { areaKey($0) == largestArea }
            guard largest.count == 1, let group = largest.first else {
                return .ambiguous
            }
            return selected(group)
        }

        // Coincident Dialog surfaces remain the compatibility fallback.
        let corroborated = groups.values.filter {
            Set($0.map(\.identity)).count >= 2
        }
        if corroborated.count == 1, let group = corroborated.first {
            return selected(group)
        }
        if corroborated.count > 1 {
            return .ambiguous
        }

        guard groups.count == 1, let group = groups.values.first else {
            return .ambiguous
        }
        return selected(group)
    }

    private static func areaKey(_ group: [PetWindowCandidate]) -> Int {
        let frame = averagedFrame(group)
        let key = FrameKey(frame: frame)
        return key.width * key.height
    }

    private static func selected(_ group: [PetWindowCandidate]) -> PetWindowSelection {
        .selected(
            memberIdentities: Set(group.map(\.identity)),
            frame: averagedFrame(group)
        )
    }

    private static func averagedFrame(_ group: [PetWindowCandidate]) -> CGRect {
        CGRect(
            x: group.map(\.frame.minX).reduce(0, +) / CGFloat(group.count),
            y: group.map(\.frame.minY).reduce(0, +) / CGFloat(group.count),
            width: group.map(\.frame.width).reduce(0, +) / CGFloat(group.count),
            height: group.map(\.frame.height).reduce(0, +) / CGFloat(group.count)
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
