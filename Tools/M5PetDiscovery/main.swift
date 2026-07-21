import AppKit
import ApplicationServices
import Foundation

private let codexBundleIdentifier = "com.openai.codex"
private let maximumTraversalDepth = 10
private let maximumTraversalNodes = 1_500
private let maximumTraversalDuration: TimeInterval = 0.75

struct AXGeometryNode {
    let element: AXUIElement
    let role: String?
    let subrole: String?
    let frame: CGRect
    let isHidden: Bool
    let isEnabled: Bool
}

struct TraversalResult {
    let nodes: [AXGeometryNode]
    let reachedDepthLimit: Bool
    let reachedNodeLimit: Bool
    let reachedTimeLimit: Bool
    let detectedCycle: Bool
    let wasCancelled: Bool
}

enum PetCoreResolution {
    case found(frame: CGRect, memberCount: Int)
    case unavailable
    case ambiguous
}

final class TraversalCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

private func attribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

private func elements(_ name: String, from element: AXUIElement) -> [AXUIElement] {
    attribute(name, from: element) as? [AXUIElement] ?? []
}

private func element(_ name: String, from element: AXUIElement) -> AXUIElement? {
    guard let value = attribute(name, from: element),
          CFGetTypeID(value) == AXUIElementGetTypeID()
    else {
        return nil
    }
    return unsafeDowncast(value, to: AXUIElement.self)
}

private func string(_ name: String, from element: AXUIElement) -> String? {
    attribute(name, from: element) as? String
}

private func bool(_ name: String, from element: AXUIElement) -> Bool? {
    attribute(name, from: element) as? Bool
}

private func axValue(_ name: String, from element: AXUIElement) -> AXValue? {
    guard let value = attribute(name, from: element),
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
        return nil
    }
    return unsafeDowncast(value, to: AXValue.self)
}

private func point(_ name: String, from element: AXUIElement) -> CGPoint? {
    guard let value = axValue(name, from: element), AXValueGetType(value) == .cgPoint else {
        return nil
    }
    var result = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &result) ? result : nil
}

private func size(_ name: String, from element: AXUIElement) -> CGSize? {
    guard let value = axValue(name, from: element), AXValueGetType(value) == .cgSize else {
        return nil
    }
    var result = CGSize.zero
    return AXValueGetValue(value, .cgSize, &result) ? result : nil
}

private func geometryNode(_ element: AXUIElement) -> AXGeometryNode? {
    guard let position = point(kAXPositionAttribute, from: element),
          let size = size(kAXSizeAttribute, from: element),
          position.x.isFinite,
          position.y.isFinite,
          size.width.isFinite,
          size.height.isFinite,
          size.width > 0,
          size.height > 0
    else {
        return nil
    }
    return AXGeometryNode(
        element: element,
        role: string(kAXRoleAttribute, from: element),
        subrole: string(kAXSubroleAttribute, from: element),
        frame: CGRect(origin: position, size: size),
        isHidden: bool(kAXHiddenAttribute, from: element) ?? false,
        isEnabled: bool(kAXEnabledAttribute, from: element) ?? true
    )
}

private func contains(_ elements: [AXUIElement], element: AXUIElement) -> Bool {
    elements.contains { CFEqual($0, element) }
}

private func selectStandardWindow(from application: AXUIElement) -> AXUIElement? {
    let windows = elements(kAXWindowsAttribute, from: application)
    let eligible = windows.filter { window in
        guard let node = geometryNode(window) else { return false }
        return !node.isHidden
            && bool(kAXMinimizedAttribute, from: window) != true
            && node.role == kAXWindowRole
            && (node.subrole == nil || node.subrole == kAXStandardWindowSubrole)
    }
    let focused = element(kAXFocusedWindowAttribute, from: application)
    if let focused, contains(eligible, element: focused) {
        return focused
    }
    let main = element(kAXMainWindowAttribute, from: application)
    if let main, contains(eligible, element: main) {
        return main
    }
    return eligible.count == 1 ? eligible[0] : nil
}

private func routeAWindowCandidates(
    application: AXUIElement,
    standardWindow: AXUIElement?
) -> [AXGeometryNode] {
    elements(kAXWindowsAttribute, from: application).compactMap { window in
        guard standardWindow.map({ !CFEqual($0, window) }) ?? true,
              let node = geometryNode(window),
              node.role == kAXWindowRole,
              node.subrole != kAXStandardWindowSubrole,
              !node.isHidden,
              bool(kAXMinimizedAttribute, from: window) != true
        else {
            return nil
        }
        return node
    }
}

private func resolvePetCore(from nodes: [AXGeometryNode]) -> PetCoreResolution {
    let eligible = nodes.filter { node in
        guard node.role == kAXWindowRole,
              node.subrole == kAXDialogSubrole
        else {
            return false
        }
        let ratio = node.frame.width / node.frame.height
        return (0.8 ... 1.5).contains(ratio)
    }
    let groups = Dictionary(grouping: eligible) { node in
        [node.frame.minX, node.frame.minY, node.frame.width, node.frame.height]
            .map { Int(($0 * 2).rounded()) }
    }
    guard groups.count == 1, let group = groups.values.first, let first = group.first else {
        return groups.isEmpty ? .unavailable : .ambiguous
    }
    return .found(frame: first.frame, memberCount: group.count)
}

private func printPetCoreResolution(prefix: String, nodes: [AXGeometryNode]) {
    switch resolvePetCore(from: nodes) {
    case let .found(_, memberCount):
        print("\(prefix) Pet core resolution: unique")
        print("\(prefix) overlapping Pet core surface count: \(memberCount)")
    case .unavailable:
        print("\(prefix) Pet core resolution: unavailable")
    case .ambiguous:
        print("\(prefix) Pet core resolution: ambiguous")
    }
}

private func traverseDescendants(
    of root: AXUIElement,
    cancellation: TraversalCancellation
) -> TraversalResult {
    let start = ContinuousClock.now
    var queue: [(AXUIElement, Int)] = elements(kAXChildrenAttribute, from: root).map { ($0, 1) }
    var nextIndex = 0
    var visited: [AXUIElement] = [root]
    var nodes: [AXGeometryNode] = []
    var reachedDepthLimit = false
    var reachedNodeLimit = false
    var reachedTimeLimit = false
    var detectedCycle = false
    var wasCancelled = false

    while nextIndex < queue.count {
        if cancellation.isCancelled() {
            wasCancelled = true
            break
        }
        if visited.count >= maximumTraversalNodes {
            reachedNodeLimit = true
            break
        }
        if start.duration(to: .now) >= .milliseconds(Int64(maximumTraversalDuration * 1_000)) {
            reachedTimeLimit = true
            break
        }

        let (candidate, depth) = queue[nextIndex]
        nextIndex += 1
        if contains(visited, element: candidate) {
            detectedCycle = true
            continue
        }
        visited.append(candidate)
        if let node = geometryNode(candidate), !node.isHidden, node.isEnabled {
            nodes.append(node)
        }
        let children = elements(kAXChildrenAttribute, from: candidate)
        if depth >= maximumTraversalDepth {
            reachedDepthLimit = reachedDepthLimit || !children.isEmpty
            continue
        }
        queue.append(contentsOf: children.map { ($0, depth + 1) })
    }

    return TraversalResult(
        nodes: nodes,
        reachedDepthLimit: reachedDepthLimit,
        reachedNodeLimit: reachedNodeLimit,
        reachedTimeLimit: reachedTimeLimit,
        detectedCycle: detectedCycle,
        wasCancelled: wasCancelled
    )
}

private func printSanitizedStructureSummary(prefix: String, nodes: [AXGeometryNode]) {
    let grouped = Dictionary(grouping: nodes) { node in
        let role = node.role ?? "unknown"
        let subrole = node.subrole ?? "none"
        return "\(role)/\(subrole)"
    }
    for kind in grouped.keys.sorted() {
        print("\(prefix) structural kind: \(kind), count: \(grouped[kind]?.count ?? 0)")
    }

    let frameGroups = Dictionary(grouping: nodes) { node in
        [node.frame.minX, node.frame.minY, node.frame.width, node.frame.height]
            .map { Int(($0 * 2).rounded()) }
    }
    let multiplicities = frameGroups.values.map(\.count).sorted()
    print("\(prefix) distinct frame count: \(frameGroups.count)")
    print("\(prefix) frame multiplicities: \(multiplicities.map(String.init).joined(separator: ","))")

    guard !nodes.isEmpty else { return }
    let minimumCenterY = nodes.map { $0.frame.midY }.min() ?? 0
    let maximumCenterY = nodes.map { $0.frame.midY }.max() ?? 0
    let minimumArea = nodes.map { $0.frame.width * $0.frame.height }.min() ?? 0
    let maximumArea = nodes.map { $0.frame.width * $0.frame.height }.max() ?? 0
    let signatures = Dictionary(grouping: nodes) { node in
        let ratio = node.frame.width / node.frame.height
        let aspect = ratio >= 1.5 ? "wide" : (ratio <= 0.8 ? "tall" : "balanced")
        let vertical: String
        if abs(node.frame.midY - minimumCenterY) <= 0.5 {
            vertical = "top"
        } else if abs(node.frame.midY - maximumCenterY) <= 0.5 {
            vertical = "bottom"
        } else {
            vertical = "middle"
        }
        let area = node.frame.width * node.frame.height
        let areaRank: String
        if abs(area - maximumArea) <= 0.5 {
            areaRank = "largest"
        } else if abs(area - minimumArea) <= 0.5 {
            areaRank = "smallest"
        } else {
            areaRank = "middle"
        }
        return "\(node.role ?? "unknown")/\(node.subrole ?? "none")"
            + ", aspect: \(aspect), vertical: \(vertical), area: \(areaRank)"
    }
    for signature in signatures.keys.sorted() {
        print("\(prefix) derived signature: \(signature), count: \(signatures[signature]?.count ?? 0)")
    }
}

private func observationDuration() -> TimeInterval? {
    guard let index = CommandLine.arguments.firstIndex(of: "--observe-movement"),
          CommandLine.arguments.indices.contains(index + 1),
          let requested = TimeInterval(CommandLine.arguments[index + 1])
    else {
        return nil
    }
    return min(max(requested, 1), 60)
}

private func lifecycleObservationDuration() -> TimeInterval? {
    guard let index = CommandLine.arguments.firstIndex(of: "--observe-lifecycle"),
          CommandLine.arguments.indices.contains(index + 1),
          let requested = TimeInterval(CommandLine.arguments[index + 1])
    else {
        return nil
    }
    return min(max(requested, 1), 45)
}

private func sanitizedSnapshotKey(_ nodes: [AXGeometryNode]) -> String {
    let kinds = Dictionary(grouping: nodes) {
        "\($0.role ?? "unknown")/\($0.subrole ?? "none")"
    }.map { "\($0.key)=\($0.value.count)" }.sorted()
    let frameGroups = Dictionary(grouping: nodes) { node in
        [node.frame.minX, node.frame.minY, node.frame.width, node.frame.height]
            .map { Int(($0 * 2).rounded()) }
    }.values.map(\.count).sorted()
    return "count=\(nodes.count);kinds=\(kinds);frames=\(frameGroups)"
}

private func observeLifecycle(
    application: AXUIElement,
    standardWindow: AXUIElement?,
    duration: TimeInterval
) {
    let deadline = Date().addingTimeInterval(duration)
    var previousKey: String?
    var transitionCount = 0
    print("Lifecycle observation: started")
    while Date() < deadline {
        let candidates = routeAWindowCandidates(
            application: application,
            standardWindow: standardWindow
        )
        let key = sanitizedSnapshotKey(candidates)
        if key != previousKey {
            transitionCount += 1
            print("Lifecycle state: \(transitionCount)")
            printSanitizedStructureSummary(prefix: "Lifecycle Route A", nodes: candidates)
            printPetCoreResolution(prefix: "Lifecycle Route A", nodes: candidates)
            previousKey = key
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    print("Lifecycle observation: complete")
    print("Lifecycle transition count: \(transitionCount)")
}

private func framesDiffer(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    abs(lhs.minX - rhs.minX) > 0.5
        || abs(lhs.minY - rhs.minY) > 0.5
        || abs(lhs.width - rhs.width) > 0.5
        || abs(lhs.height - rhs.height) > 0.5
}

private func selectedTargetObservationDuration() -> TimeInterval? {
    guard let index = CommandLine.arguments.firstIndex(of: "--observe-pet-target"),
          CommandLine.arguments.indices.contains(index + 1),
          let requested = TimeInterval(CommandLine.arguments[index + 1])
    else {
        return nil
    }
    return min(max(requested, 1), 30)
}

private func observeSelectedPetTarget(
    application: AXUIElement,
    standardWindow: AXUIElement?,
    duration: TimeInterval
) {
    let initialCandidates = routeAWindowCandidates(
        application: application,
        standardWindow: standardWindow
    )
    guard case let .found(initialFrame, _) = resolvePetCore(from: initialCandidates) else {
        print("Selected Pet target observation: unavailable at start")
        return
    }
    let initialStandardFrame = standardWindow.flatMap(geometryNode)?.frame
    var targetMoved = false
    var standardMoved = false
    var uniqueSamples = 0
    var unavailableSamples = 0
    var ambiguousSamples = 0
    let deadline = Date().addingTimeInterval(duration)
    print("Selected Pet target observation: started")
    while Date() < deadline {
        let candidates = routeAWindowCandidates(
            application: application,
            standardWindow: standardWindow
        )
        switch resolvePetCore(from: candidates) {
        case let .found(frame, _):
            uniqueSamples += 1
            targetMoved = targetMoved || framesDiffer(initialFrame, frame)
        case .unavailable:
            unavailableSamples += 1
        case .ambiguous:
            ambiguousSamples += 1
        }
        if let standardWindow,
           let initialStandardFrame,
           let frame = geometryNode(standardWindow)?.frame
        {
            standardMoved = standardMoved || framesDiffer(initialStandardFrame, frame)
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    print("Selected Pet target observation: complete")
    print("Pet core independent movement: \(targetMoved ? "observed" : "not observed")")
    print("Pet core unique samples: \(uniqueSamples)")
    print("Pet core unavailable samples: \(unavailableSamples)")
    print("Pet core ambiguous samples: \(ambiguousSamples)")
    print("Codex standard window stationary: \(standardMoved ? "no" : "yes")")
}

private func observeMovement(
    candidates: [AXGeometryNode],
    standardWindow: AXUIElement?,
    duration: TimeInterval
) {
    let initialStandardFrame = standardWindow.flatMap(geometryNode)?.frame
    var changedCandidates = Set<Int>()
    var disappearedCandidates = Set<Int>()
    var latestFrames: [Int: CGRect] = [:]
    var standardWindowChanged = false
    let deadline = Date().addingTimeInterval(duration)
    print("Movement observation: started")
    while Date() < deadline {
        for (index, candidate) in candidates.enumerated() {
            guard let current = geometryNode(candidate.element) else {
                disappearedCandidates.insert(index)
                continue
            }
            if framesDiffer(candidate.frame, current.frame) {
                changedCandidates.insert(index)
            }
            latestFrames[index] = current.frame
        }
        if let standardWindow,
           let initialStandardFrame,
           let current = geometryNode(standardWindow)?.frame,
           framesDiffer(initialStandardFrame, current)
        {
            standardWindowChanged = true
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    print("Movement observation: complete")
    print("Geometry-changing candidate count: \(changedCandidates.count)")
    let distinctTrajectories = Set(changedCandidates.compactMap { index -> [Int]? in
        guard let latest = latestFrames[index] else { return nil }
        let initial = candidates[index].frame
        return [
            latest.minX - initial.minX,
            latest.minY - initial.minY,
            latest.width - initial.width,
            latest.height - initial.height,
        ].map { Int(($0 * 2).rounded()) }
    }).count
    print("Distinct changed trajectory count: \(distinctTrajectories)")
    print("Candidate disappearance observed: \(disappearedCandidates.isEmpty ? "no" : "yes")")
    print("Codex standard window stationary: \(standardWindowChanged ? "no" : "yes")")
}

let shouldRequestAccessibility = CommandLine.arguments.dropFirst().contains(
    "--request-accessibility"
)
let accessibilityAvailable: Bool
if shouldRequestAccessibility {
    let options = ["AXTrustedCheckOptionPrompt": true]
    accessibilityAvailable = AXIsProcessTrustedWithOptions(options as CFDictionary)
} else {
    accessibilityAvailable = AXIsProcessTrusted()
}

guard accessibilityAvailable else {
    print("Accessibility permission: unavailable")
    print(shouldRequestAccessibility
        ? "Accessibility permission request: issued explicitly"
        : "Automatic permission prompt: not issued")
    exit(2)
}
print("Accessibility permission: available")

let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: codexBundleIdentifier
)
let selectedApplication: NSRunningApplication?
if applications.count == 1 {
    selectedApplication = applications[0]
} else {
    let active = applications.filter(\.isActive)
    selectedApplication = active.count == 1 ? active[0] : nil
}
guard let selectedApplication else {
    print("Exact Codex process: unavailable or ambiguous")
    exit(3)
}
print("Exact Codex process: found")

let application = AXUIElementCreateApplication(selectedApplication.processIdentifier)
let standardWindow = selectStandardWindow(from: application)
print("Codex standard window: \(standardWindow == nil ? "unavailable or ambiguous" : "resolved")")

let routeA = routeAWindowCandidates(application: application, standardWindow: standardWindow)
print("Route A candidate count: \(routeA.count)")
printSanitizedStructureSummary(prefix: "Route A", nodes: routeA)
printPetCoreResolution(prefix: "Route A", nodes: routeA)
let shouldContinueToRouteB = CommandLine.arguments.dropFirst().contains("--route-b")
if !routeA.isEmpty, !shouldContinueToRouteB {
    print("Route B traversal: not attempted while Route A has candidates")
    if let duration = lifecycleObservationDuration() {
        observeLifecycle(
            application: application,
            standardWindow: standardWindow,
            duration: duration
        )
    } else if let duration = selectedTargetObservationDuration() {
        observeSelectedPetTarget(
            application: application,
            standardWindow: standardWindow,
            duration: duration
        )
    } else if let duration = observationDuration() {
        observeMovement(
            candidates: routeA,
            standardWindow: standardWindow,
            duration: duration
        )
    }
    exit(0)
}
if !routeA.isEmpty {
    print("Route A candidates rejected by prior direct movement validation")
}

guard let standardWindow else {
    print("Route B traversal: unavailable without a deterministic standard window")
    exit(4)
}
let traversalCancellation = TraversalCancellation()
signal(SIGINT, SIG_IGN)
let cancellationSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
cancellationSource.setEventHandler {
    traversalCancellation.cancel()
}
cancellationSource.resume()
let traversal = traverseDescendants(
    of: standardWindow,
    cancellation: traversalCancellation
)
cancellationSource.cancel()
print("Route B geometry node count: \(traversal.nodes.count)")
print("Route B depth bound reached: \(traversal.reachedDepthLimit ? "yes" : "no")")
print("Route B node bound reached: \(traversal.reachedNodeLimit ? "yes" : "no")")
print("Route B time bound reached: \(traversal.reachedTimeLimit ? "yes" : "no")")
print("Route B cycle detected: \(traversal.detectedCycle ? "yes" : "no")")
print("Route B traversal cancelled: \(traversal.wasCancelled ? "yes" : "no")")
printSanitizedStructureSummary(prefix: "Route B", nodes: traversal.nodes)
if let duration = observationDuration() {
    observeMovement(
        candidates: traversal.nodes,
        standardWindow: standardWindow,
        duration: duration
    )
}
