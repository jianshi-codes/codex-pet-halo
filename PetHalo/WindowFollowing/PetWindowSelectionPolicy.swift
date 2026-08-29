import CoreGraphics
import Foundation

struct PetWindowCandidate: Equatable, Sendable {
    let identity: Int
    let frame: CGRect
    let isMinimized: Bool
    let isHidden: Bool
    let role: String?
    let subrole: String?

    var isEligibleCoreWindow: Bool {
        guard !isMinimized,
              !isHidden,
              frame.hasFiniteComponents,
              frame.width > 0,
              frame.height > 0,
              role == "AXWindow",
              subrole != "AXStandardWindow"
        else {
            return false
        }
        return true
    }

    var isEligibleCoreGeometry: Bool {
        guard isEligibleCoreWindow else { return false }
        return (0.8 ... 1.5).contains(frame.width / frame.height)
    }

    var isEligibleCoreSurface: Bool {
        isEligibleCoreGeometry && (subrole == "AXDialog" || subrole == "AXSystemDialog")
    }

    var isCompatibilityCoreSurface: Bool {
        isEligibleCoreGeometry && !isEligibleCoreSurface
    }

    var isCompatibilityDialogWindow: Bool {
        guard isEligibleCoreWindow, subrole == "AXDialog" else { return false }
        let aspectRatio = frame.width / frame.height
        return aspectRatio <= 2.5
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
        let eligible = candidates.filter(\.isEligibleCoreGeometry)
        let grouped = Dictionary(grouping: eligible, by: { FrameKey(frame: $0.frame) })
        let groups = removeContainingWrappers(Array(grouped.values))
        guard !groups.isEmpty else {
            // The current Desktop build exposes one visible Pet AXDialog with a
            // tall non-square frame. Keep extremely wide activity surfaces out.
            let dialogCandidates = candidates.filter(\.isCompatibilityDialogWindow)
            let dialogGroups = Dictionary(
                grouping: dialogCandidates,
                by: { FrameKey(frame: $0.frame) }
            )
            guard dialogGroups.count == 1, let group = dialogGroups.values.first else {
                return dialogGroups.isEmpty ? .unavailable : .ambiguous
            }
            return selected(group)
        }

        // Prefer the known Codex Pet surface. Smaller balanced SystemDialogs are controls,
        // while coincident Dialogs may retain stale geometry across Tuck Away and Wake.
        let systemDialogGroups = groups.filter {
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

        // Coincident Dialog surfaces remain the primary compatibility fallback.
        let dialogGroups = groups.filter {
            $0.contains(where: { $0.subrole == "AXDialog" })
        }
        let corroborated = dialogGroups.filter {
            Set($0.map(\.identity)).count >= 2
        }
        if corroborated.count == 1, let group = corroborated.first {
            return selected(group)
        }
        if corroborated.count > 1 {
            return .ambiguous
        }

        if dialogGroups.count > 1 {
            return .ambiguous
        }
        if dialogGroups.count == 1, let group = dialogGroups.first {
            return selected(group)
        }

        // Some Desktop builds may keep the geometry but change the subrole. Accept only
        // one non-standard near-square surface; multiple unknown surfaces remain ambiguous.
        let compatibilityGroups = groups.filter {
            $0.contains(where: \.isCompatibilityCoreSurface)
        }
        guard compatibilityGroups.count == 1, let group = compatibilityGroups.first else {
            return compatibilityGroups.isEmpty ? .unavailable : .ambiguous
        }
        return selected(group)
    }

    private static func removeContainingWrappers(
        _ groups: [[PetWindowCandidate]]
    ) -> [[PetWindowCandidate]] {
        groups.filter { outerGroup in
            guard outerGroup.allSatisfy(\.isCompatibilityCoreSurface) else {
                return true
            }
            let outerFrame = averagedFrame(outerGroup)
            return !groups.contains { innerGroup in
                guard innerGroup.allSatisfy(\.isCompatibilityCoreSurface) else {
                    return false
                }
                let innerFrame = averagedFrame(innerGroup)
                guard frameArea(outerFrame) > frameArea(innerFrame) else {
                    return false
                }
                return substantiallyContains(outerFrame, innerFrame)
            }
        }
    }

    private static func substantiallyContains(_ outer: CGRect, _ inner: CGRect) -> Bool {
        let intersection = outer.intersection(inner)
        guard !intersection.isNull,
              intersection.width > 0,
              intersection.height > 0,
              frameArea(inner) > 0
        else {
            return false
        }
        return frameArea(intersection) >= frameArea(inner) * 0.9
    }

    private static func frameArea(_ frame: CGRect) -> CGFloat {
        frame.width * frame.height
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
