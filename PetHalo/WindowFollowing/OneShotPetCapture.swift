import AppKit
// Older SDKs lack concurrency annotations on ScreenCaptureKit result types.
@preconcurrency import ScreenCaptureKit

@MainActor
enum OneShotPetCapture {
    static func capturePet(processIdentifier: Int32) async -> CGRect? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true
            )
            let candidates = content.windows.filter {
                $0.owningApplication?.processID == processIdentifier
                    && $0.owningApplication?.bundleIdentifier == "com.openai.codex"
                    && $0.windowLayer == 3
                    && $0.frame.width >= 640 && $0.frame.height >= 640
            }
            guard candidates.count == 1, let window = candidates.first else { return nil }
            guard window.frame.width <= 8192, window.frame.height <= 8192,
                window.frame.width * window.frame.height <= 20_000_000
            else { return nil }
            let configuration = SCStreamConfiguration()
            configuration.width = Int((window.frame.width / 2).rounded(.up))
            configuration.height = Int((window.frame.height / 2).rounded(.up))
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.shouldBeOpaque = false
            // ScreenCaptureKit's default background is transparent.
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window),
                configuration: configuration
            )
            let body = await Task.detached(priority: .userInitiated) {
                PetAlphaDetector.petFrame(in: image)
            }.value
            guard let body, let primary = NSScreen.screens.first?.frame else { return nil }
            let frame = CGRect(
                x: window.frame.minX + body.minX * window.frame.width / CGFloat(image.width),
                y: window.frame.minY + body.minY * window.frame.height / CGFloat(image.height),
                width: body.width * window.frame.width / CGFloat(image.width),
                height: body.height * window.frame.height / CGFloat(image.height)
            )
            return AXCoordinateConverter(primaryDisplayFrame: primary)
                .appKitFrame(fromAccessibilityFrame: frame)
        } catch {
            return nil
        }
    }
}
