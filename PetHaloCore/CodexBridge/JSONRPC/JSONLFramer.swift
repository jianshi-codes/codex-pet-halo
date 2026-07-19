import Foundation

public enum JSONLFramingError: Error, Equatable, Sendable {
    case invalidUTF8
    case messageTooLarge
}

public struct JSONLFramer: Sendable {
    public static let defaultMaximumMessageSize = 4 * 1_024 * 1_024

    private var buffer = Data()
    private let maximumMessageSize: Int

    public init(maximumMessageSize: Int = defaultMaximumMessageSize) {
        precondition(maximumMessageSize > 0)
        self.maximumMessageSize = maximumMessageSize
        buffer.reserveCapacity(min(maximumMessageSize, 64 * 1_024))
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        var messages: [Data] = []
        for byte in data {
            if byte == 0x0A {
                if !buffer.isEmpty {
                    guard let line = String(data: buffer, encoding: .utf8) else {
                        throw JSONLFramingError.invalidUTF8
                    }
                    if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messages.append(buffer)
                    }
                }
                buffer.removeAll(keepingCapacity: true)
                continue
            }

            guard buffer.count < maximumMessageSize else {
                throw JSONLFramingError.messageTooLarge
            }
            buffer.append(byte)
        }
        return messages
    }

    public var bufferedByteCount: Int {
        buffer.count
    }
}
