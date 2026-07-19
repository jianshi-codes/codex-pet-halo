import Foundation

public protocol JSONRPCTransport: Sendable {
    func start() async throws
    func send(_ data: Data) async throws
    func inboundMessages() async -> AsyncThrowingStream<Data, Error>
    func stop() async
}

public protocol RequestSleeping: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct ContinuousRequestSleeper: RequestSleeping, Sendable {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

public struct JSONRPCTimeoutPolicy: Equatable, Sendable {
    public let initialize: Duration
    public let normal: Duration

    public init(initialize: Duration = .seconds(10), normal: Duration = .seconds(15)) {
        self.initialize = initialize
        self.normal = normal
    }
}

public enum AllowedRequestMethod: String, Equatable, Sendable {
    case initialize
    case accountRead = "account/read"
    case rateLimitsRead = "account/rateLimits/read"
    case accountUsageRead = "account/usage/read"
}

public enum AllowedNotificationMethod: String, Equatable, Sendable {
    case initialized
}

public enum JSONRPCClientError: Error, Equatable, Sendable {
    case notStarted
    case alreadyStarted
    case encodingFailed
    case invalidMessage
    case remoteError(code: Int)
    case requestTimedOut
    case transportClosed
    case cancelled
    case duplicateResponse
}

public enum JSONRPCEvent: Equatable, Sendable {
    case notification(method: String, params: JSONValue?)
    case disconnected(JSONRPCClientError)
}

private struct OutgoingRequest: Encodable {
    let method: String
    let id: Int64
    let params: JSONValue?

    enum CodingKeys: CodingKey {
        case method
        case id
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encode(id, forKey: .id)
        if let params {
            try container.encode(params, forKey: .params)
        }
    }
}

private struct OutgoingNotification: Encodable {
    let method: String
}

private struct IncomingError: Decodable {
    let code: Int
}

private struct IncomingEnvelope: Decodable {
    let id: JSONRPCID?
    let method: String?
    let params: JSONValue?
    let result: JSONValue?
    let error: IncomingError?
    let containsResult: Bool

    enum CodingKeys: CodingKey {
        case id
        case method
        case params
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(JSONRPCID.self, forKey: .id)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        params = try container.decodeIfPresent(JSONValue.self, forKey: .params)
        result = try container.decodeIfPresent(JSONValue.self, forKey: .result)
        error = try container.decodeIfPresent(IncomingError.self, forKey: .error)
        containsResult = container.contains(.result)
    }
}

public actor JSONRPCClient {
    private enum Lifecycle {
        case idle
        case starting
        case open
        case closing
        case closed
    }

    private struct PendingRequest {
        let continuation: CheckedContinuation<JSONValue, Error>
        let timeoutTask: Task<Void, Never>
    }

    private let transport: any JSONRPCTransport
    private let timeoutPolicy: JSONRPCTimeoutPolicy
    private let sleeper: any RequestSleeping
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let eventStream: AsyncStream<JSONRPCEvent>
    private let eventContinuation: AsyncStream<JSONRPCEvent>.Continuation

    private var nextRequestID: Int64 = 1
    private var pending: [JSONRPCID: PendingRequest] = [:]
    private var completedResponseIDs = Set<JSONRPCID>()
    private var completedResponseOrder: [JSONRPCID] = []
    private var readTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var cleanupWaiters: [CheckedContinuation<Void, Never>] = []
    private var lifecycle = Lifecycle.idle

    public init(
        transport: any JSONRPCTransport,
        timeoutPolicy: JSONRPCTimeoutPolicy = JSONRPCTimeoutPolicy(),
        sleeper: any RequestSleeping = ContinuousRequestSleeper()
    ) {
        self.transport = transport
        self.timeoutPolicy = timeoutPolicy
        self.sleeper = sleeper
        let pair = AsyncStream.makeStream(
            of: JSONRPCEvent.self,
            bufferingPolicy: .bufferingNewest(64)
        )
        eventStream = pair.stream
        eventContinuation = pair.continuation
    }

    public func events() -> AsyncStream<JSONRPCEvent> {
        eventStream
    }

    public func start() async throws {
        guard lifecycle == .idle else {
            if lifecycle == .closed || lifecycle == .closing {
                throw JSONRPCClientError.transportClosed
            }
            throw JSONRPCClientError.alreadyStarted
        }
        lifecycle = .starting
        do {
            try await transport.start()
        } catch {
            await shutdown(error: .transportClosed, emitDisconnect: false)
            throw JSONRPCClientError.transportClosed
        }
        guard lifecycle == .starting else {
            await waitForCleanupBarrier()
            throw JSONRPCClientError.transportClosed
        }
        lifecycle = .open
        let stream = await transport.inboundMessages()
        guard lifecycle == .open else {
            await waitForCleanupBarrier()
            throw JSONRPCClientError.transportClosed
        }
        readTask = Task { [weak self] in
            do {
                for try await data in stream {
                    guard let self else { return }
                    await self.receive(data)
                }
                guard let self else { return }
                await self.connectionClosed(.transportClosed)
            } catch is CancellationError {
                // Intentional shutdown owns cancellation propagation.
            } catch {
                guard let self else { return }
                await self.connectionClosed(.transportClosed)
            }
        }
    }

    public func request(
        _ method: AllowedRequestMethod,
        params: JSONValue? = nil
    ) async throws -> JSONValue {
        guard lifecycle == .open else {
            throw JSONRPCClientError.notStarted
        }
        let requestID = nextRequestID
        nextRequestID += 1
        let rpcID = JSONRPCID.integer(requestID)
        let outgoing = OutgoingRequest(method: method.rawValue, id: requestID, params: params)
        guard var data = try? encoder.encode(outgoing) else {
            throw JSONRPCClientError.encodingFailed
        }
        data.append(0x0A)
        let outboundData = data
        let timeout = method == .initialize ? timeoutPolicy.initialize : timeoutPolicy.normal

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeoutTask = Task { [weak self, sleeper] in
                    do {
                        try await sleeper.sleep(for: timeout)
                    } catch {
                        return
                    }
                    guard let self else { return }
                    await self.timeout(rpcID)
                }
                pending[rpcID] = PendingRequest(
                    continuation: continuation,
                    timeoutTask: timeoutTask
                )

                Task { [weak self, transport] in
                    do {
                        try await transport.send(outboundData)
                    } catch {
                        guard let self else { return }
                        await self.connectionClosed(.transportClosed)
                    }
                }
            }
        } onCancel: {
            Task { [weak self] in
                await self?.failRequest(rpcID, with: .cancelled)
            }
        }
    }

    public func notify(_ method: AllowedNotificationMethod) async throws {
        guard lifecycle == .open else {
            throw JSONRPCClientError.notStarted
        }
        guard var data = try? encoder.encode(OutgoingNotification(method: method.rawValue)) else {
            throw JSONRPCClientError.encodingFailed
        }
        data.append(0x0A)
        do {
            try await transport.send(data)
        } catch {
            await connectionClosed(.transportClosed)
            throw JSONRPCClientError.transportClosed
        }
    }

    public func close() async {
        await shutdown(error: .cancelled, emitDisconnect: false)
    }

    private func receive(_ data: Data) async {
        guard lifecycle == .open else { return }
        let envelope: IncomingEnvelope
        do {
            envelope = try decoder.decode(IncomingEnvelope.self, from: data)
        } catch {
            await connectionClosed(.invalidMessage)
            return
        }

        if let method = envelope.method {
            guard envelope.id == nil else {
                await connectionClosed(.invalidMessage)
                return
            }
            eventContinuation.yield(.notification(method: method, params: envelope.params))
            return
        }

        guard let id = envelope.id else {
            await connectionClosed(.invalidMessage)
            return
        }
        if completedResponseIDs.contains(id) {
            await connectionClosed(.duplicateResponse)
            return
        }
        guard let request = pending.removeValue(forKey: id) else {
            return
        }
        request.timeoutTask.cancel()
        rememberCompleted(id)

        if let error = envelope.error {
            request.continuation.resume(throwing: JSONRPCClientError.remoteError(code: error.code))
        } else if envelope.containsResult {
            request.continuation.resume(returning: envelope.result ?? .null)
        } else {
            request.continuation.resume(throwing: JSONRPCClientError.invalidMessage)
            await connectionClosed(.invalidMessage)
        }
    }

    private func rememberCompleted(_ id: JSONRPCID) {
        completedResponseIDs.insert(id)
        completedResponseOrder.append(id)
        if completedResponseOrder.count > 4_096 {
            let removed = completedResponseOrder.removeFirst()
            completedResponseIDs.remove(removed)
        }
    }

    private func timeout(_ id: JSONRPCID) {
        failRequest(id, with: .requestTimedOut)
    }

    private func failRequest(_ id: JSONRPCID, with error: JSONRPCClientError) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.timeoutTask.cancel()
        request.continuation.resume(throwing: error)
    }

    private func failAll(with error: JSONRPCClientError) {
        let requests = pending.values
        pending.removeAll()
        for request in requests {
            request.timeoutTask.cancel()
            request.continuation.resume(throwing: error)
        }
    }

    private func connectionClosed(_ error: JSONRPCClientError) async {
        await shutdown(error: error, emitDisconnect: true)
    }

    private func shutdown(
        error: JSONRPCClientError,
        emitDisconnect: Bool
    ) async {
        if lifecycle == .closing {
            await withCheckedContinuation { continuation in
                cleanupWaiters.append(continuation)
            }
            return
        }
        if lifecycle == .closed {
            return
        }

        lifecycle = .closing
        let activeReadTask = readTask
        readTask = nil
        activeReadTask?.cancel()
        failAll(with: error)
        let cleanup = Task { [transport] in
            await transport.stop()
        }
        cleanupTask = cleanup
        await cleanup.value

        guard lifecycle == .closing else { return }
        lifecycle = .closed
        cleanupTask = nil
        if emitDisconnect {
            eventContinuation.yield(.disconnected(error))
        }
        eventContinuation.finish()
        let waiters = cleanupWaiters
        cleanupWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func waitForCleanupBarrier() async {
        if lifecycle == .closing {
            await withCheckedContinuation { continuation in
                cleanupWaiters.append(continuation)
            }
        }
    }
}
