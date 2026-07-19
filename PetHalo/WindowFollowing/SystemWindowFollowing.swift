import AppKit
import ApplicationServices
import Foundation

enum WindowFollowingSystemEvent: Equatable, Sendable {
    case codexEnvironmentChanged
    case displayConfigurationChanged
}

@MainActor
protocol WindowFollowingSystemEventSourcing: AnyObject {
    func events() -> AsyncStream<WindowFollowingSystemEvent>
    func start()
    func stop()
}

@MainActor
final class WorkspaceWindowFollowingEventSource: WindowFollowingSystemEventSourcing {
    private let stream: AsyncStream<WindowFollowingSystemEvent>
    private let continuation: AsyncStream<WindowFollowingSystemEvent>.Continuation
    private var workspaceTokens: [NSObjectProtocol] = []
    private var displayToken: NSObjectProtocol?
    private var started = false

    init() {
        let pair = AsyncStream.makeStream(
            of: WindowFollowingSystemEvent.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func events() -> AsyncStream<WindowFollowingSystemEvent> {
        stream
    }

    func start() {
        guard !started else { return }
        started = true
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            let token = workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                    application.bundleIdentifier == CodexApplicationSelector.bundleIdentifier
                else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.continuation.yield(.codexEnvironmentChanged)
                }
            }
            workspaceTokens.append(token)
        }
        let displayToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuation.yield(.displayConfigurationChanged)
            }
        }
        self.displayToken = displayToken
    }

    func stop() {
        guard started else { return }
        started = false
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens {
            workspaceCenter.removeObserver(token)
        }
        workspaceTokens.removeAll()
        if let displayToken {
            NotificationCenter.default.removeObserver(displayToken)
            self.displayToken = nil
        }
    }
}

@MainActor
protocol AccessibilityPermissionProviding: AnyObject {
    func state() -> WindowFollowingPermissionState
    func request() -> WindowFollowingPermissionState
}

@MainActor
final class SystemAccessibilityPermissionProvider: AccessibilityPermissionProviding {
    func state() -> WindowFollowingPermissionState {
        AXIsProcessTrusted() ? .granted : .notGranted
    }

    func request() -> WindowFollowingPermissionState {
        let options = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary) ? .granted : .notGranted
    }
}

@MainActor
protocol CodexApplicationLocating: AnyObject {
    func locate() -> CodexApplicationSelection
}

@MainActor
final class WorkspaceCodexApplicationLocator: CodexApplicationLocating {
    func locate() -> CodexApplicationSelection {
        let candidates = NSRunningApplication.runningApplications(
            withBundleIdentifier: CodexApplicationSelector.bundleIdentifier
        ).map { application in
            CodexApplicationCandidate(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier,
                isActive: application.isActive
            )
        }
        return CodexApplicationSelector.select(from: candidates)
    }
}

enum CodexWindowObservationEvent: Equatable, Sendable {
    case geometryChanged
    case selectionChanged
    case targetInvalidated
}

enum CodexWindowAccessResult: Equatable, Sendable {
    case selected(frame: CGRect)
    case unavailable
    case ambiguous
    case observerFailed
}

@MainActor
protocol CodexWindowAccessing: AnyObject {
    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (CodexWindowObservationEvent, Int) -> Void
    ) -> CodexWindowAccessResult
    func currentFrame() -> CGRect?
    func stop()
}

final class AXCallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private let generation: Int
    private let handler: @MainActor (CodexWindowObservationEvent, Int) -> Void
    private var pending: CodexWindowObservationEvent?
    private var scheduled = false
    private var active = true

    init(
        generation: Int,
        handler: @escaping @MainActor (CodexWindowObservationEvent, Int) -> Void
    ) {
        self.generation = generation
        self.handler = handler
    }

    func enqueue(_ event: CodexWindowObservationEvent) {
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
            try? await Task.sleep(for: .milliseconds(50))
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
        _ current: CodexWindowObservationEvent?,
        _ incoming: CodexWindowObservationEvent
    ) -> CodexWindowObservationEvent {
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
final class AccessibilityCodexWindowAccessor: CodexWindowAccessing {
    private var applicationElement: AXUIElement?
    private var targetElement: AXUIElement?
    private var observer: AXObserver?
    private var callbackBox: AXCallbackBox?

    func resolve(
        processIdentifier: Int32,
        generation: Int,
        onEvent: @escaping @MainActor (CodexWindowObservationEvent, Int) -> Void
    ) -> CodexWindowAccessResult {
        stop()
        let application = AXUIElementCreateApplication(processIdentifier)
        let windows = elementArray(attribute: kAXWindowsAttribute, from: application)
        let focused = element(attribute: kAXFocusedWindowAttribute, from: application)
        let main = element(attribute: kAXMainWindowAttribute, from: application)
        let candidates = windows.enumerated().map { index, window in
            CodexWindowCandidate(
                identity: index,
                frame: accessibilityFrame(of: window) ?? .zero,
                isFocused: focused.map { CFEqual($0, window) } ?? false,
                isMain: main.map { CFEqual($0, window) } ?? false,
                isMinimized: bool(attribute: kAXMinimizedAttribute, from: window) ?? false,
                isVisible: true,
                role: string(attribute: kAXRoleAttribute, from: window),
                subrole: string(attribute: kAXSubroleAttribute, from: window)
            )
        }

        let selectedIndex: Int
        switch CodexWindowSelector.select(from: candidates) {
        case .unavailable:
            return .unavailable
        case .ambiguous:
            return .ambiguous
        case let .selected(identity):
            selectedIndex = identity
        }
        guard windows.indices.contains(selectedIndex) else { return .unavailable }
        let target = windows[selectedIndex]
        guard let frame = appKitFrame(of: target) else { return .unavailable }

        var newObserver: AXObserver?
        let result = AXObserverCreate(
            processIdentifier,
            { _, _, notification, reference in
                guard let reference else { return }
                let box = Unmanaged<AXCallbackBox>.fromOpaque(reference).takeUnretainedValue()
                let name = notification as String
                switch name {
                case kAXMovedNotification, kAXResizedNotification:
                    box.enqueue(.geometryChanged)
                case kAXUIElementDestroyedNotification:
                    box.enqueue(.targetInvalidated)
                case kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification:
                    box.enqueue(.selectionChanged)
                case kAXFocusedWindowChangedNotification,
                     kAXMainWindowChangedNotification,
                     kAXWindowCreatedNotification:
                    box.enqueue(.selectionChanged)
                default:
                    break
                }
            },
            &newObserver
        )
        guard result == .success, let newObserver else { return .observerFailed }

        let box = AXCallbackBox(generation: generation, handler: onEvent)
        let reference = Unmanaged.passUnretained(box).toOpaque()
        for notification in [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
        ] {
            guard AXObserverAddNotification(newObserver, target, notification as CFString, reference)
                == .success
            else {
                box.deactivate()
                return .observerFailed
            }
        }
        for notification in [
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
            kAXWindowCreatedNotification,
        ] {
            _ = AXObserverAddNotification(newObserver, application, notification as CFString, reference)
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(newObserver),
            .commonModes
        )
        applicationElement = application
        targetElement = target
        observer = newObserver
        callbackBox = box
        return .selected(frame: frame)
    }

    func currentFrame() -> CGRect? {
        targetElement.flatMap(appKitFrame(of:))
    }

    func stop() {
        callbackBox?.deactivate()
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            if let targetElement {
                for notification in [
                    kAXMovedNotification,
                    kAXResizedNotification,
                    kAXUIElementDestroyedNotification,
                    kAXWindowMiniaturizedNotification,
                    kAXWindowDeminiaturizedNotification,
                ] {
                    _ = AXObserverRemoveNotification(observer, targetElement, notification as CFString)
                }
            }
            if let applicationElement {
                for notification in [
                    kAXFocusedWindowChangedNotification,
                    kAXMainWindowChangedNotification,
                    kAXWindowCreatedNotification,
                ] {
                    _ = AXObserverRemoveNotification(observer, applicationElement, notification as CFString)
                }
            }
        }
        callbackBox = nil
        observer = nil
        targetElement = nil
        applicationElement = nil
    }

    private func appKitFrame(of element: AXUIElement) -> CGRect? {
        guard let accessibilityFrame = accessibilityFrame(of: element),
              let primaryFrame = NSScreen.screens.first?.frame
        else {
            return nil
        }
        return AXCoordinateConverter(primaryDisplayFrame: primaryFrame)
            .appKitFrame(fromAccessibilityFrame: accessibilityFrame)
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

    private func element(attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
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
