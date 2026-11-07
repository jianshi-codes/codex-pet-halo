import AppKit
import SwiftUI

// Render the production SwiftUI surface with synthetic data; no screen capture.
@main
struct ResetRingPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = CommandLine.arguments.dropFirst().first ?? "docs/assets/screenshots"
        for (name, remaining, orientation, side) in [
            ("reset-ring-ahead", 39.0, PetRingOrientation.openingTop, PetRingLabelSide.right),
            ("reset-ring-within-pace", 65.0, PetRingOrientation.openingBottom, PetRingLabelSide.left)
        ] {
            let weekly = RingMetricValue(
                remainingPercent: remaining, displayedPercent: Int(remaining),
                semanticLevel: PetRingPresentationPolicy.remainingLevel(for: remaining),
                resetsAt: Date().addingTimeInterval(302_400)
            )
            let model = PetRingPresentationModel(weekly: .current(weekly), fiveHour: nil,
                                                  accessibilityValue: "Synthetic preview")
            let view = VStack(spacing: 8) {
                Text(remaining < 50 ? "Usage ahead of time" : "Usage within time budget")
                    .font(.headline)
                PetRingView(model: model, orientation: orientation, labelSide: side)
                Text("Weekly quota: \(Int(remaining))% left · Reset time: 50% left")
                    .font(.system(size: 12))
                Text("Thin blue inner arc = time until weekly reset")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("Could not render preview") }
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("Could not encode preview")
            }
            try pixelsOnlyPNG(png).write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
        }
    }

    // Keep only image chunks so previews contain no incidental export metadata.
    private static func pixelsOnlyPNG(_ data: Data) -> Data {
        var result = Data(data.prefix(8))
        var offset = 8
        while offset + 12 <= data.count {
            let length = data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            let end = offset + length + 12
            let type = String(decoding: data[(offset + 4)..<(offset + 8)], as: UTF8.self)
            if ["IHDR", "IDAT", "IEND"].contains(type) {
                result.append(data[offset..<end])
            }
            offset = end
        }
        return result
    }

}
