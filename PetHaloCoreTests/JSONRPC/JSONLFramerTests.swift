import XCTest
@testable import PetHaloCore

final class JSONLFramerTests: XCTestCase {
    func testPartialLinesMultipleMessagesAndBlankLines() throws {
        var framer = JSONLFramer(maximumMessageSize: 100)

        XCTAssertTrue(try framer.append(Data("{\"id\":1".utf8)).isEmpty)
        let messages = try framer.append(Data("}\n\n  \n{\"id\":2}\n".utf8))

        XCTAssertEqual(messages.map { String(decoding: $0, as: UTF8.self) }, ["{\"id\":1}", "{\"id\":2}"])
        XCTAssertEqual(framer.bufferedByteCount, 0)
    }

    func testInvalidUTF8IsRejected() throws {
        var framer = JSONLFramer(maximumMessageSize: 100)

        XCTAssertThrowsError(try framer.append(Data([0xFF, 0x0A]))) { error in
            XCTAssertEqual(error as? JSONLFramingError, .invalidUTF8)
        }
    }

    func testOversizedLineIsRejectedWithoutUnboundedBuffering() throws {
        var framer = JSONLFramer(maximumMessageSize: 4)

        XCTAssertThrowsError(try framer.append(Data("12345".utf8))) { error in
            XCTAssertEqual(error as? JSONLFramingError, .messageTooLarge)
        }
        XCTAssertEqual(framer.bufferedByteCount, 4)
    }
}
