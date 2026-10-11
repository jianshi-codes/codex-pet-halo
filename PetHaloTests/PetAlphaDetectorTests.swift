import CoreGraphics
import XCTest
@testable import PetHalo

final class PetAlphaDetectorTests: XCTestCase {
    func testFindsBodyAndIgnoresHorizontalControls() {
        let image = pixels(rectangles: [
            CGRect(x: 20, y: 20, width: 160, height: 24),
            CGRect(x: 70, y: 60, width: 50, height: 80),
            CGRect(x: 55, y: 150, width: 80, height: 24),
        ])
        XCTAssertEqual(
            PetAlphaDetector.select(PetAlphaDetector.regions(rgba: image, width: 200, height: 200)),
            CGRect(x: 70, y: 60, width: 50, height: 80)
        )
    }

    func testTwoPossibleBodiesFailClosed() {
        let image = pixels(rectangles: [
            CGRect(x: 20, y: 50, width: 40, height: 80),
            CGRect(x: 120, y: 50, width: 40, height: 80),
        ])
        XCTAssertNil(PetAlphaDetector.select(
            PetAlphaDetector.regions(rgba: image, width: 200, height: 200)
        ))
    }

    func testTransparentFrameAndTinyNoiseDoNotSelectPet() {
        let image = pixels(rectangles: [CGRect(x: 20, y: 20, width: 8, height: 8)])
        XCTAssertNil(PetAlphaDetector.select(
            PetAlphaDetector.regions(rgba: image, width: 200, height: 200)
        ))
        XCTAssertTrue(PetAlphaDetector.regions(rgba: [], width: 200, height: 200).isEmpty)
    }

    private func pixels(rectangles: [CGRect]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 200 * 200 * 4)
        for rectangle in rectangles {
            for y in Int(rectangle.minY)..<Int(rectangle.maxY) {
                for x in Int(rectangle.minX)..<Int(rectangle.maxX) {
                    result[(y * 200 + x) * 4 + 3] = 255
                }
            }
        }
        return result
    }
}
