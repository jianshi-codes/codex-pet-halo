import AppKit
import ApplicationServices
import Foundation

let bundleIdentifier = "com.openai.codex"
guard AXIsProcessTrusted() else {
    print("Accessibility permission state: unavailable")
    print("Codex application discovery: not attempted")
    print("Target window selection: not attempted")
    exit(0)
}
print("Accessibility permission state: available")

let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
let selectedApplication: NSRunningApplication?
if applications.count == 1 {
    selectedApplication = applications[0]
} else {
    let active = applications.filter(\.isActive)
    selectedApplication = active.count == 1 ? active[0] : nil
}
guard let selectedApplication else {
    print("Codex application discovery: unavailable or ambiguous")
    print("Target window selection: not attempted")
    exit(0)
}
print("Codex application discovery: pass")

func attribute(_ name: String, element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

func boolAttribute(_ name: String, element: AXUIElement) -> Bool? {
    attribute(name, element: element) as? Bool
}

func stringAttribute(_ name: String, element: AXUIElement) -> String? {
    attribute(name, element: element) as? String
}

func elementAttribute(_ name: String, element: AXUIElement) -> AXUIElement? {
    guard let value = attribute(name, element: element),
          CFGetTypeID(value) == AXUIElementGetTypeID()
    else {
        return nil
    }
    return unsafeDowncast(value, to: AXUIElement.self)
}

func axValue(_ name: String, element: AXUIElement) -> AXValue? {
    guard let value = attribute(name, element: element),
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
        return nil
    }
    return unsafeDowncast(value, to: AXValue.self)
}

func hasPositiveGeometry(_ element: AXUIElement) -> Bool {
    guard let value = axValue(kAXSizeAttribute, element: element),
          AXValueGetType(value) == .cgSize
    else {
        return false
    }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) && size.width > 0 && size.height > 0
}

let applicationElement = AXUIElementCreateApplication(selectedApplication.processIdentifier)
let windows = attribute(kAXWindowsAttribute, element: applicationElement) as? [AXUIElement] ?? []
let focused = elementAttribute(kAXFocusedWindowAttribute, element: applicationElement)
let main = elementAttribute(kAXMainWindowAttribute, element: applicationElement)
let eligible = windows.filter { window in
    stringAttribute(kAXRoleAttribute, element: window) == "AXWindow"
        && (stringAttribute(kAXSubroleAttribute, element: window) == nil
            || stringAttribute(kAXSubroleAttribute, element: window) == "AXStandardWindow")
        && boolAttribute(kAXMinimizedAttribute, element: window) != true
        && hasPositiveGeometry(window)
}

let focusedEligible = eligible.filter { window in focused.map { CFEqual($0, window) } ?? false }
let mainEligible = eligible.filter { window in main.map { CFEqual($0, window) } ?? false }
if focusedEligible.count == 1
    || (focusedEligible.isEmpty && mainEligible.count == 1)
    || (focusedEligible.isEmpty && mainEligible.isEmpty && eligible.count == 1)
{
    print("Target window selection: pass")
} else {
    print(eligible.isEmpty
        ? "Target window selection: unavailable"
        : "Target window selection: ambiguous")
}
