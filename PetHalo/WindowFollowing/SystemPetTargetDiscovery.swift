import AppKit
import ApplicationServices
import Foundation

enum PetTargetObservationEvent: Equatable, Sendable {
    case geometryChanged
    case activityGeometryChanged
    case selectionChanged
    case targetInvalidated
}

enum PetTargetAccessResult: Equatable, Sendable {
    case selected(PetTargetSnapshot)
    case unavailable
    case ambiguous
    case observerFailed
}

@MainActor
protocol PetTargetAccessing: AnyObject {
    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (PetTargetObservationEvent, Int) -> Void
    ) -> PetTargetAccessResult
    func currentSnapshot() -> PetTargetSnapshot?
    func currentTrackedFrame() -> PetTrackedFrameSample?
    func stop()
}

final class PetAXCallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private let generation: Int
    private let handler: @MainActor (PetTargetObservationEvent, Int) -> Void
    private let petElements: [AXUIElement]
    private let activityElements: [AXUIElement]
    private var pending: PetTargetObservationEvent?
    private var scheduled = false
    private var active = true

    init(
        generation: Int,
        petElements: [AXUIElement] = [],
        activityElements: [AXUIElement] = [],
        handler: @escaping @MainActor (PetTargetObservationEvent, Int) -> Void
    ) {
        self.generation = generation
        self.petElements = petElements
        self.activityElements = activityElements
        self.handler = handler
    }

    func enqueue(notification: String, element: AXUIElement) {
        if notification == kAXWindowCreatedNotification as String {
            enqueue(.selectionChanged)
            return
        }
        let isPet = petElements.contains { CFEqual($0, element) }
        let isActivity = activityElements.contains { CFEqual($0, element) }
        switch notification {
        case kAXMovedNotification, kAXResizedNotification:
            if isPet {
                enqueue(.geometryChanged)
            } else if isActivity {
                enqueue(.activityGeometryChanged)
            }
        case kAXUIElementDestroyedNotification:
            enqueue(isPet ? .targetInvalidated : .activityGeometryChanged)
        default:
            break
        }
    }

    func enqueue(_ event: PetTargetObservationEvent) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        pending = merged(pending, event)
        let shouldSchedule = !scheduled
        scheduled = true
        lock.unlock()
        guard shouldSchedule else { return }

        Task { @MainActor [weak self] in
            self?.deliver()
        }
    }

    func deactivate() {
        lock.lock()
        active = false
        pending = nil
        lock.unlock()
    }

    @MainActor
    private func deliver() {
        lock.lock()
        let event = active ? pending : nil
        pending = nil
        scheduled = false
        lock.unlock()
        if let event {
            handler(event, generation)
        }
    }

    private func merged(
        _ current: PetTargetObservationEvent?,
        _ incoming: PetTargetObservationEvent
    ) -> PetTargetObservationEvent {
        if current == .targetInvalidated || incoming == .targetInvalidated {
            return .targetInvalidated
        }
        if current == .selectionChanged || incoming == .selectionChanged {
            return .selectionChanged
        }
        if current == .geometryChanged || incoming == .geometryChanged {
            return .geometryChanged
        }
        return .activityGeometryChanged
    }
}

@MainActor
final class AccessibilityPetTargetAccessor: PetTargetAccessing {
    private struct Selection {
        let observedIdentities: Set<Int>
        let activityObservedIdentities: Set<Int>
        let petFrame: CGRect
        let activityGeometryHint: PetActivityGeometryHint
        let activityVerticalDelta: Double?
    }

    private var applicationElement: AXUIElement?
    private var targetElements: [AXUIElement] = []
    private var activityElements: [AXUIElement] = []
    private var observer: AXObserver?
    private var callbackBox: PetAXCallbackBox?
    private var generation = 0

    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (PetTargetObservationEvent, Int) -> Void
    ) -> PetTargetAccessResult {
        stop()
        let application = AXUIElementCreateApplication(processIdentifier)
        let windows = elementArray(attribute: kAXWindowsAttribute, from: application)
        let selectionResult = select(from: windows)
        let selection: Selection
        switch selectionResult {
        case .unavailable:
            return .unavailable
        case .ambiguous:
            return .ambiguous
        case let .selected(selected):
            selection = selected
        }
        let selectedElements = windows.enumerated().compactMap { index, element in
            selection.observedIdentities.contains(index) ? element : nil
        }
        let selectedActivityElements = windows.enumerated().compactMap { index, element in
            selection.activityObservedIdentities.contains(index) ? element : nil
        }
        guard !selectedElements.isEmpty,
              let petFrame = appKitFrame(fromAccessibilityFrame: selection.petFrame)
        else {
            return .unavailable
        }
        var newObserver: AXObserver?
        let observerResult = AXObserverCreate(
            processIdentifier,
            { _, element, notification, reference in
                guard let reference else { return }
                let box = Unmanaged<PetAXCallbackBox>.fromOpaque(reference)
                    .takeUnretainedValue()
                box.enqueue(notification: notification as String, element: element)
            },
            &newObserver
        )
        guard observerResult == .success, let newObserver else {
            return .observerFailed
        }

        let box = PetAXCallbackBox(
            generation: generation,
            petElements: selectedElements,
            activityElements: selectedActivityElements,
            handler: onEvent
        )
        let reference = Unmanaged.passUnretained(box).toOpaque()
        for target in selectedElements {
            for notification in [
                kAXMovedNotification,
                kAXResizedNotification,
                kAXUIElementDestroyedNotification,
            ] {
                guard AXObserverAddNotification(
                    newObserver,
                    target,
                    notification as CFString,
                    reference
                ) == .success else {
                    box.deactivate()
                    return .observerFailed
                }
            }
        }
        for activity in selectedActivityElements {
            for notification in [
                kAXMovedNotification,
                kAXResizedNotification,
                kAXUIElementDestroyedNotification,
            ] {
                guard AXObserverAddNotification(
                    newObserver,
                    activity,
                    notification as CFString,
                    reference
                ) == .success else {
                    box.deactivate()
                    return .observerFailed
                }
            }
        }
        guard AXObserverAddNotification(
            newObserver,
            application,
            kAXWindowCreatedNotification as CFString,
            reference
        ) == .success else {
            box.deactivate()
            return .observerFailed
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(newObserver),
            .commonModes
        )
        applicationElement = application
        targetElements = selectedElements
        activityElements = selectedActivityElements
        observer = newObserver
        callbackBox = box
        self.generation = generation
        return .selected(PetTargetSnapshot(
            generation: generation,
            frame: petFrame,
            activityGeometryHint: selection.activityGeometryHint,
            activityVerticalDelta: selection.activityVerticalDelta
        ))
    }

    func currentSnapshot() -> PetTargetSnapshot? {
        guard let applicationElement else { return nil }
        let windows = elementArray(attribute: kAXWindowsAttribute, from: applicationElement)
        guard case let .selected(selection) = select(from: windows),
              let petFrame = appKitFrame(fromAccessibilityFrame: selection.petFrame)
        else {
            return nil
        }
        return PetTargetSnapshot(
            generation: generation,
            frame: petFrame,
            activityGeometryHint: selection.activityGeometryHint,
            activityVerticalDelta: selection.activityVerticalDelta
        )
    }

    func currentTrackedFrame() -> PetTrackedFrameSample? {
        guard !targetElements.isEmpty else { return nil }
        let frames = targetElements.compactMap(accessibilityFrame(of:))
        guard frames.count == targetElements.count,
              let frame = PetTrackedFrameResolver.resolve(frames),
              let appKitFrame = appKitFrame(fromAccessibilityFrame: frame)
        else {
            return nil
        }
        return PetTrackedFrameSample(generation: generation, frame: appKitFrame)
    }

    func stop() {
        callbackBox?.deactivate()
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            for target in targetElements {
                for notification in [
                    kAXMovedNotification,
                    kAXResizedNotification,
                    kAXUIElementDestroyedNotification,
                ] {
                    _ = AXObserverRemoveNotification(
                        observer,
                        target,
                        notification as CFString
                    )
                }
            }
            for activity in activityElements {
                for notification in [
                    kAXMovedNotification,
                    kAXResizedNotification,
                    kAXUIElementDestroyedNotification,
                ] {
                    _ = AXObserverRemoveNotification(
                        observer,
                        activity,
                        notification as CFString
                    )
                }
            }
            if let applicationElement {
                _ = AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXWindowCreatedNotification as CFString
                )
            }
        }
        callbackBox = nil
        observer = nil
        targetElements.removeAll()
        activityElements.removeAll()
        applicationElement = nil
    }

    private enum SelectionResult {
        case unavailable
        case selected(Selection)
        case ambiguous
    }

    private func select(from windows: [AXUIElement]) -> SelectionResult {
        let candidates = windows.enumerated().map { index, window in
            PetWindowCandidate(
                identity: index,
                frame: accessibilityFrame(of: window) ?? .zero,
                isMinimized: bool(attribute: kAXMinimizedAttribute, from: window) ?? false,
                isHidden: bool(attribute: kAXHiddenAttribute, from: window) ?? false,
                role: string(attribute: kAXRoleAttribute, from: window),
                subrole: string(attribute: kAXSubroleAttribute, from: window)
            )
        }
        switch PetWindowSelector.select(from: candidates) {
        case .unavailable:
            return .unavailable
        case .ambiguous:
            return .ambiguous
        case let .selected(memberIdentities, petFrame):
            let activity = PetActivityGeometryResolver.resolve(
                petFrame: petFrame,
                petMemberIdentities: memberIdentities,
                candidates: candidates
            )
            return .selected(Selection(
                observedIdentities: memberIdentities,
                activityObservedIdentities: activity.observedIdentities,
                petFrame: petFrame,
                activityGeometryHint: activity.hint,
                activityVerticalDelta: activity.activityVerticalDelta
            ))
        }
    }

    private func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect? {
        guard let primaryFrame = NSScreen.screens.first?.frame else { return nil }
        return AXCoordinateConverter(primaryDisplayFrame: primaryFrame)
            .appKitFrame(fromAccessibilityFrame: frame)
    }

    private func accessibilityFrame(of element: AXUIElement) -> CGRect? {
        guard let position = point(attribute: kAXPositionAttribute, from: element),
              let size = size(attribute: kAXSizeAttribute, from: element)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func elementArray(attribute: String, from element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let array = value as? [AXUIElement]
        else {
            return []
        }
        return array
    }

    private func bool(attribute: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value as? Bool
    }

    private func string(attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value as? String
    }

    private func point(attribute: String, from element: AXUIElement) -> CGPoint? {
        guard let value = axValue(attribute: attribute, from: element),
              AXValueGetType(value) == .cgPoint
        else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func size(attribute: String, from element: AXUIElement) -> CGSize? {
        guard let value = axValue(attribute: attribute, from: element),
              AXValueGetType(value) == .cgSize
        else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValue(attribute: String, from element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
    }
}
