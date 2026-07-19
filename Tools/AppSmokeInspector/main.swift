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

let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let ownedWindows = windowInfo.filter { info in
    (info[kCGWindowOwnerPID as String] as? Int32) == pid
}
guard ownedWindows.isEmpty else {
    fputs("error: application owns a visible window\n", stderr)
    exit(1)
}

print("Application running: yes")
print("Activation policy: accessory")
print("Normal windows: none")
print("Dock icon: absent by accessory policy")
