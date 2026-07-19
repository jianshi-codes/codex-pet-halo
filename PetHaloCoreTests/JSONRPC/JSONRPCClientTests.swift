import Foundation
import XCTest
@testable import PetHaloCore

private actor InMemoryTransport: JSONRPCTransport {
    private let stream: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private(set) var sent: [Data] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        let pair = AsyncThrowingStream.makeStream(of: Data.self, throwing: Error.self)
        stream = pair.stream
        continuation = pair.continuation
    }

    func start() async throws {
        startCount += 1
    }

    func send(_ data: Data) async throws {
        sent.append(data)
    }

    func inboundMessages() async -> AsyncThrowingStream<Data, Error> {
        stream
    }

    func stop() async {
        stopCount += 1
        continuation.finish()
    }

    func emit(_ json: String) {
        continuation.yield(Data(json.utf8))
    }

    func disconnect() {
        continuation.finish(throwing: JSONRPCClientError.transportClosed)
    }
}

private actor ManualSleeper: RequestSleeping {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let pair = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(16))
        stream = pair.stream
        continuation = pair.continuation
    }

    func sleep(for duration: Duration) async throws {
        var iterator = stream.makeAsyncIterator()
        guard await iterator.next() != nil else {
            throw CancellationError()
        }
    }

    func fire() {
        continuation.yield(())
    }
}

final class JSONRPCClientTests: XCTestCase {
    func testSequentialIDsAndOutOfOrderResponses() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()

        let first = Task { try await client.request(.rateLimitsRead) }
        let second = Task { try await client.request(.accountUsageRead) }
        let sent = try await waitForSentMessages(2, transport: transport)
        let ids = try sent.map(requestID)
        let methodsAndIDs = try Dictionary(uniqueKeysWithValues: sent.map { data in
            (try requestMethod(data), try requestID(data))
        })

        XCTAssertEqual(ids, [1, 2])
        let rateID = try XCTUnwrap(methodsAndIDs["account/rateLimits/read"])
        let usageID = try XCTUnwrap(methodsAndIDs["account/usage/read"])
        await transport.emit("{\"id\":\(usageID),\"result\":{\"value\":2}}")
        await transport.emit("{\"id\":\(rateID),\"result\":{\"value\":1}}")

        let firstValue = try await first.value
        let secondValue = try await second.value
        XCTAssertEqual(firstValue, .object(["value": .integer(1)]))
        XCTAssertEqual(secondValue, .object(["value": .integer(2)]))
        await client.close()
    }

    func testErrorResponseUsesOnlySafeCode() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let request = Task { try await client.request(.accountUsageRead) }
        _ = try await waitForSentMessages(1, transport: transport)
        await transport.emit("{\"id\":1,\"error\":{\"code\":-32601,\"message\":\"sensitive\"}}")

        do {
            _ = try await request.value
            XCTFail("Expected remote error")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .remoteError(code: -32_601))
        }
        await client.close()
    }

    func testNotificationsDispatchExactMethodAndUnknownMethod() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let events = await client.events()
        var iterator = events.makeAsyncIterator()

        await transport.emit("{\"method\":\"account/rateLimits/updated\",\"params\":{}}")
        await transport.emit("{\"method\":\"future/unknown\",\"params\":null}")

        let rateNotification = await iterator.next()
        let unknownNotification = await iterator.next()
        XCTAssertEqual(
            rateNotification,
            .notification(method: "account/rateLimits/updated", params: .object([:]))
        )
        XCTAssertEqual(
            unknownNotification,
            .notification(method: "future/unknown", params: nil)
        )
        await client.close()
    }

    func testUnknownResponseIDIsIgnored() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let request = Task { try await client.request(.rateLimitsRead) }
        _ = try await waitForSentMessages(1, transport: transport)

        await transport.emit("{\"id\":99,\"result\":null}")
        await transport.emit("{\"id\":1,\"result\":{}}")
        let value = try await request.value
        XCTAssertEqual(value, .object([:]))
        await client.close()
    }

    func testDuplicateResponseClosesConnection() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let events = await client.events()
        var iterator = events.makeAsyncIterator()
        let request = Task { try await client.request(.rateLimitsRead) }
        _ = try await waitForSentMessages(1, transport: transport)
        await transport.emit("{\"id\":1,\"result\":{}}")
        _ = try await request.value
        await transport.emit("{\"id\":1,\"result\":{}}")

        let event = await iterator.next()
        XCTAssertEqual(event, .disconnected(.duplicateResponse))
    }

    func testInvalidJSONClosesConnection() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let events = await client.events()
        var iterator = events.makeAsyncIterator()
        await transport.emit("not-json")

        let event = await iterator.next()
        XCTAssertEqual(event, .disconnected(.invalidMessage))
    }

    func testTimeoutIsInjectableAndDeterministic() async throws {
        let transport = InMemoryTransport()
        let sleeper = ManualSleeper()
        let client = JSONRPCClient(transport: transport, sleeper: sleeper)
        try await client.start()
        let request = Task { try await client.request(.rateLimitsRead) }
        _ = try await waitForSentMessages(1, transport: transport)
        await sleeper.fire()

        do {
            _ = try await request.value
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .requestTimedOut)
        }
        await client.close()
    }

    func testCancellationAndDisconnectPropagateToPendingRequests() async throws {
        let transport = InMemoryTransport()
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let cancelled = Task { try await client.request(.rateLimitsRead) }
        _ = try await waitForSentMessages(1, transport: transport)
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .cancelled)
        }

        let disconnected = Task { try await client.request(.accountUsageRead) }
        _ = try await waitForSentMessages(2, transport: transport)
        await transport.disconnect()
        do {
            _ = try await disconnected.value
            XCTFail("Expected disconnect")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .transportClosed)
        }
    }

    private func waitForSentMessages(
        _ count: Int,
        transport: InMemoryTransport
    ) async throws -> [Data] {
        for _ in 0 ..< 1_000 {
            let messages = await transport.sent
            if messages.count >= count {
                return messages
            }
            await Task.yield()
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func requestID(_ data: Data) throws -> Int {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(object?["id"] as? Int)
    }

    private func requestMethod(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(object?["method"] as? String)
    }
}
