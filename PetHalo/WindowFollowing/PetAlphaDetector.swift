import CoreGraphics
import Foundation

struct AlphaRegion: Equatable {
    let frame: CGRect
    let pixelCount: Int
}
enum PetAlphaDetector {
    static func petFrame(in image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, width <= 8192, height <= 8192,
            width * height <= 20_000_000
        else { return nil }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let info =
            CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let context = CGContext(
                data: &rgba, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // A transparent overlay must remain mostly empty; reject an opaque capture.
        let opaqueCount = stride(from: 3, to: rgba.count, by: 4).reduce(0) {
            $0 + (rgba[$1] >= 160 ? 1 : 0)
        }
        guard opaqueCount < width * height / 5 else { return nil }
        return select(regions(rgba: rgba, width: width, height: height))
    }
    static func regions(rgba: [UInt8], width: Int, height: Int) -> [AlphaRegion] {
        guard width > 0, height > 0, rgba.count == width * height * 4 else { return [] }
        var visited = [Bool](repeating: false, count: width * height)
        var result: [AlphaRegion] = []
        for start in 0..<(width * height) where !visited[start] && rgba[start * 4 + 3] >= 160 {
            var queue = [start]
            visited[start] = true
            var i = 0
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0
            while i < queue.count {
                let p = queue[i]
                i += 1
                let x = p % width
                let y = p / width
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                        let next = ny * width + nx
                        if !visited[next] && rgba[next * 4 + 3] >= 160 {
                            visited[next] = true
                            queue.append(next)
                        }
                    }
                }
            }
            if queue.count >= 100 {
                result.append(
                    AlphaRegion(
                        frame: CGRect(
                            x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
                        pixelCount: queue.count))
            }
        }
        return result
    }
    static func select(_ regions: [AlphaRegion]) -> CGRect? {
        let candidates = regions.filter {
            let f = $0.frame
            return f.width >= 24 && f.height >= 40 && f.width <= 320 && f.height <= 320
                && (0.3...1.6).contains(f.width / f.height)
                && Double($0.pixelCount) / Double(f.width * f.height) >= 0.15
        }
        return candidates.count == 1 ? candidates[0].frame : nil
    }
}
