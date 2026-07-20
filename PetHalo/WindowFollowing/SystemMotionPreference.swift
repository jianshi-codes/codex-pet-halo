import AppKit

@MainActor
struct SystemMotionPreference {
    var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
