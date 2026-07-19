import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2,
      let pid = Int32(CommandLine.arguments[1]),
      let application = NSRunningApplication(processIdentifier: pid)
else {
    fputs("error: running application unavailable\n", stderr)
    exit(1)
}

guard application.activationPolicy == .accessory else {
    fputs("error: application is not accessory-only\n", stderr)
    exit(1)
}

guard !application.isActive else {
    fputs("error: application activated while presenting Halo\n", stderr)
    exit(1)
}

let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let ownedWindows = windowInfo.filter { info in
    (info[kCGWindowOwnerPID as String] as? Int32) == pid
}
guard ownedWindows.count == 1 else {
    fputs("error: expected exactly one visible Halo window\n", stderr)
    exit(1)
}

guard let bounds = ownedWindows[0][kCGWindowBounds as String] as? [String: NSNumber],
      bounds["Width"]?.doubleValue == 176,
      bounds["Height"]?.doubleValue == 176
else {
    fputs("error: visible window is not the compact Halo\n", stderr)
    exit(1)
}

print("Application running: yes")
print("Activation policy: accessory")
print("Halo window: one compact panel")
print("Application activation: unchanged")
print("Normal windows: none beyond Halo")
print("Dock icon: absent by accessory policy")
