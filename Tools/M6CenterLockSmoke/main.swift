import AppKit
import ApplicationServices
import Foundation

private let codexBundleIdentifier = "com.openai.codex"
private let petHaloBundleIdentifier = "io.github.jianshicodes.PetHalo"
private let preferencesDomain = "io.github.jianshicodes.PetHalo"
private let petAnchorKey = "io.github.jianshicodes.PetHalo.petFollowing.anchor.v1"
private let windowAnchorKey = "io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1"

private struct WindowGeometry {
    let frame: CGRect
    let minimized: Bool
    let hidden: Bool
    let role: String?
    let subrole: String?
}

private func attribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

private func point(_ name: String, from element: AXUIElement) -> CGPoint? {
    guard let value = attribute(name, from: element),
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
        return nil
    }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgPoint else { return nil }
    var result = CGPoint.zero
    return AXValueGetValue(axValue, .cgPoint, &result) ? result : nil
}

private func size(_ name: String, from element: AXUIElement) -> CGSize? {
    guard let value = attribute(name, from: element),
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
        return nil
    }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgSize else { return nil }
    var result = CGSize.zero
    return AXValueGetValue(axValue, .cgSize, &result) ? result : nil
}

private func windows(from application: AXUIElement) -> [WindowGeometry] {
    let elements = attribute(kAXWindowsAttribute, from: application) as? [AXUIElement] ?? []
    return elements.compactMap { element in
        guard let position = point(kAXPositionAttribute, from: element),
              let dimensions = size(kAXSizeAttribute, from: element),
              position.x.isFinite,
              position.y.isFinite,
              dimensions.width.isFinite,
              dimensions.height.isFinite,
              dimensions.width > 0,
              dimensions.height > 0
        else {
            return nil
        }
        return WindowGeometry(
            frame: CGRect(origin: position, size: dimensions),
            minimized: attribute(kAXMinimizedAttribute, from: element) as? Bool ?? false,
            hidden: attribute(kAXHiddenAttribute, from: element) as? Bool ?? false,
            role: attribute(kAXRoleAttribute, from: element) as? String,
            subrole: attribute(kAXSubroleAttribute, from: element) as? String
        )
    }
}

private func petCore(from candidates: [WindowGeometry]) -> CGRect? {
    let eligible = candidates.filter {
        !$0.minimized && !$0.hidden
            && $0.role == "AXWindow" && $0.subrole == "AXDialog"
            && (0.8 ... 1.5).contains($0.frame.width / $0.frame.height)
    }
    let groups = Dictionary(grouping: eligible) {
        [$0.frame.minX, $0.frame.minY, $0.frame.width, $0.frame.height]
            .map { Int(($0 * 2).rounded()) }
    }
    guard groups.count == 1, let group = groups.values.first else { return nil }
    let count = CGFloat(group.count)
    return CGRect(
        x: group.map(\.frame.minX).reduce(0, +) / count,
        y: group.map(\.frame.minY).reduce(0, +) / count,
        width: group.map(\.frame.width).reduce(0, +) / count,
        height: group.map(\.frame.height).reduce(0, +) / count
    )
}

private func appKitFrame(_ accessibilityFrame: CGRect) -> CGRect? {
    guard let primary = NSScreen.screens.first?.frame else { return nil }
    return CGRect(
        x: accessibilityFrame.minX,
        y: primary.maxY - accessibilityFrame.minY - accessibilityFrame.height,
        width: accessibilityFrame.width,
        height: accessibilityFrame.height
    )
}

private func changed(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    abs(lhs.minX - rhs.minX) > 0.5 || abs(lhs.minY - rhs.minY) > 0.5
        || abs(lhs.width - rhs.width) > 0.5 || abs(lhs.height - rhs.height) > 0.5
}

private func haloPanelFrame() -> CGRect? {
    let applications = NSRunningApplication.runningApplications(
        withBundleIdentifier: petHaloBundleIdentifier
    )
    guard applications.count == 1 else { return nil }
    let application = AXUIElementCreateApplication(applications[0].processIdentifier)
    let candidates = windows(from: application).filter {
        !$0.minimized && !$0.hidden
            && ((abs($0.frame.width - 176) <= 1 && abs($0.frame.height - 176) <= 1)
                || (abs($0.frame.width - 360) <= 1 && abs($0.frame.height - 520) <= 1))
    }
    guard candidates.count == 1 else { return nil }
    return appKitFrame(candidates[0].frame)
}

private func centersAreAligned(panelFrame: CGRect, petFrame: CGRect) -> Bool {
    abs(panelFrame.midX - petFrame.midX) <= 1
        && abs(panelFrame.midY - petFrame.midY) <= 1
}

guard AXIsProcessTrusted() else {
    print("Accessibility permission: unavailable")
    exit(2)
}
print("Accessibility permission: available")

let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: codexBundleIdentifier
)
let selectedApplication = applications.count == 1
    ? applications[0]
    : applications.filter(\.isActive).only
guard let selectedApplication else {
    print("Exact Codex process: unavailable or ambiguous")
    exit(3)
}
print("Exact Codex process: found")

let savedPetAnchor = CFPreferencesCopyAppValue(
    petAnchorKey as CFString,
    preferencesDomain as CFString
) != nil
let savedWindowAnchor = CFPreferencesCopyAppValue(
    windowAnchorKey as CFString,
    preferencesDomain as CFString
) != nil
print("Legacy Pet anchor: \(savedPetAnchor ? "present" : "absent")")
print("M4 window anchor: \(savedWindowAnchor ? "present" : "absent")")

let application = AXUIElementCreateApplication(selectedApplication.processIdentifier)
let initialPetHaloApplications = NSRunningApplication.runningApplications(
    withBundleIdentifier: petHaloBundleIdentifier
)
guard initialPetHaloApplications.count == 1 else {
    print("Exact Pet Halo process: unavailable or ambiguous")
    exit(4)
}
print("Exact Pet Halo process: found")

let initialPetFrame = petCore(from: windows(from: application)).flatMap(appKitFrame)
print("Pet visible at start: \(initialPetFrame == nil ? "no" : "yes")")

let duration = CommandLine.arguments.dropFirst().first.flatMap(TimeInterval.init) ?? 60
let deadline = Date().addingTimeInterval(min(max(duration, 10), 120))
var firstPetFrame = initialPetFrame
var lastPetPresent = initialPetFrame != nil
var disappearanceObserved = false
var wakeObserved = false
var movementObserved = false
var attachmentObserved = false
var fallbackObserved = false
var quitObserved = false
var initialAlignmentObserved = false
var movementAlignmentObserved = false
var wakeAlignmentObserved = false

while Date() < deadline {
    let petHaloRunning = NSRunningApplication.runningApplications(
        withBundleIdentifier: petHaloBundleIdentifier
    ).count == 1
    if !petHaloRunning {
        quitObserved = true
        if disappearanceObserved && wakeObserved { break }
    }

    let candidates = windows(from: application)
    if let accessibilityPetFrame = petCore(from: candidates),
       let petFrame = appKitFrame(accessibilityPetFrame)
    {
        if disappearanceObserved && !lastPetPresent { wakeObserved = true }
        lastPetPresent = true
        if let firstPetFrame {
            movementObserved = movementObserved || changed(firstPetFrame, petFrame)
        } else {
            firstPetFrame = petFrame
        }

        if let panelFrame = haloPanelFrame() {
            attachmentObserved = true
            if centersAreAligned(panelFrame: panelFrame, petFrame: petFrame) {
                initialAlignmentObserved = true
                if movementObserved {
                    movementAlignmentObserved = true
                }
                if wakeObserved {
                    wakeAlignmentObserved = true
                }
            }
        }
    } else {
        disappearanceObserved = disappearanceObserved || lastPetPresent
        lastPetPresent = false
        if disappearanceObserved, savedWindowAnchor, haloPanelFrame() != nil {
            fallbackObserved = true
        }
    }
    Thread.sleep(forTimeInterval: 0.1)
}

let centerAlignmentMaintained = initialAlignmentObserved
    && movementAlignmentObserved
    && wakeAlignmentObserved
print("Pet target found: \(firstPetFrame == nil ? "no" : "yes")")
print("Automatic attachment: \(attachmentObserved ? "observed" : "not observed")")
print("Center alignment sample: \(initialAlignmentObserved ? "observed" : "not observed")")
print("Post-movement center alignment: \(movementAlignmentObserved ? "observed" : "not observed")")
print("Post-Wake center alignment: \(wakeAlignmentObserved ? "observed" : "not observed")")
print("Center alignment maintained: \(centerAlignmentMaintained ? "yes" : "no")")
print("Independent Pet movement: \(movementObserved ? "observed" : "not observed")")
print("Pet Tuck Away: \(disappearanceObserved ? "observed" : "not observed")")
print("Codex-window fallback: \(fallbackObserved ? "observed" : "not observed")")
print("Pet Wake: \(wakeObserved ? "observed" : "not observed")")
print("Pet Halo Quit: \(quitObserved ? "observed" : "not observed")")

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}
