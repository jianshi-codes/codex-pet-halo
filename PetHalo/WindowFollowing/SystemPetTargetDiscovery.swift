import AppKit
import ApplicationServices
import Foundation

enum PetTargetObservationEvent: Equatable, Sendable {
    case geometryChanged
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
    func stop()
}

final class PetAXCallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private let generation: Int
    private let handler: @MainActor (PetTargetObservationEvent, Int) -> Void
    private var pending: PetTargetObservationEvent?
    private var scheduled = false
    private var active = true

    init(
        generation: Int,
        handler: @escaping @MainActor (PetTargetObservationEvent, Int) -> Void
    ) {
        self.generation = generation
        self.handler = handler
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
            try? await Task.sleep(for: .milliseconds(80))
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
        return .geometryChanged
    }
}

@MainActor
final class AccessibilityPetTargetAccessor: PetTargetAccessing {
    private var applicationElement: AXUIElement?
    private var targetElements: [AXUIElement] = []
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
        let selection = select(from: windows)
        let memberIdentities: Set<Int>
        let frame: CGRect
        switch selection {
        case .unavailable:
            return .unavailable
        case .ambiguous:
            return .ambiguous
        case let .selected(identities, selectedFrame):
            memberIdentities = identities
            frame = selectedFrame
        }
        let selectedElements = windows.enumerated().compactMap { index, element in
            memberIdentities.contains(index) ? element : nil
        }
        guard !selectedElements.isEmpty,
              let appKitFrame = appKitFrame(fromAccessibilityFrame: frame)
        else {
            return .unavailable
        }

        var newObserver: AXObserver?
        let observerResult = AXObserverCreate(
            processIdentifier,
            { _, _, notification, reference in
                guard let reference else { return }
                let box = Unmanaged<PetAXCallbackBox>.fromOpaque(reference)
                    .takeUnretainedValue()
                switch notification as String {
                case kAXMovedNotification, kAXResizedNotification:
                    box.enqueue(.geometryChanged)
                case kAXUIElementDestroyedNotification:
                    box.enqueue(.targetInvalidated)
                case kAXWindowCreatedNotification:
                    box.enqueue(.selectionChanged)
                default:
                    break
                }
            },
            &newObserver
        )
        guard observerResult == .success, let newObserver else {
            return .observerFailed
        }

        let box = PetAXCallbackBox(generation: generation, handler: onEvent)
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
        observer = newObserver
        callbackBox = box
        self.generation = generation
        return .selected(PetTargetSnapshot(generation: generation, frame: appKitFrame))
    }

    func currentSnapshot() -> PetTargetSnapshot? {
        guard let applicationElement else { return nil }
        let windows = elementArray(attribute: kAXWindowsAttribute, from: applicationElement)
        guard case let .selected(_, frame) = select(from: windows),
              let appKitFrame = appKitFrame(fromAccessibilityFrame: frame)
        else {
            return nil
        }
        return PetTargetSnapshot(generation: generation, frame: appKitFrame)
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
        applicationElement = nil
    }

    private func select(from windows: [AXUIElement]) -> PetWindowSelection {
        PetWindowSelector.select(from: windows.enumerated().map { index, window in
            PetWindowCandidate(
                identity: index,
                frame: accessibilityFrame(of: window) ?? .zero,
                isMinimized: bool(attribute: kAXMinimizedAttribute, from: window) ?? false,
                isHidden: bool(attribute: kAXHiddenAttribute, from: window) ?? false,
                role: string(attribute: kAXRoleAttribute, from: window),
                subrole: string(attribute: kAXSubroleAttribute, from: window)
            )
        })
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
