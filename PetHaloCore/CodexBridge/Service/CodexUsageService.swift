import Foundation
import OSLog

public protocol BridgeClock: Sendable {
    func dateNow() -> Date
    func monotonicNanoseconds() -> UInt64
    func sleep(nanoseconds: UInt64) async throws
}

public struct SystemBridgeClock: BridgeClock, Sendable {
    public init() {}

    public func dateNow() -> Date {
        Date()
    }

    public func monotonicNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(for: .nanoseconds(Int64(clamping: nanoseconds)))
    }
}

public struct RefreshPolicy: Equatable, Sendable {
    public let rateLimitsNanoseconds: UInt64
    public let accountUsageNanoseconds: UInt64
    public let notificationDebounceNanoseconds: UInt64

    public init(
        rateLimitsNanoseconds: UInt64 = 60_000_000_000,
        accountUsageNanoseconds: UInt64 = 900_000_000_000,
        notificationDebounceNanoseconds: UInt64 = 250_000_000
    ) {
        precondition(rateLimitsNanoseconds > 0)
        precondition(accountUsageNanoseconds > 0)
        self.rateLimitsNanoseconds = rateLimitsNanoseconds
        self.accountUsageNanoseconds = accountUsageNanoseconds
        self.notificationDebounceNanoseconds = notificationDebounceNanoseconds
    }
}

public struct ReconnectPolicy: Equatable, Sendable {
    public let delaysNanoseconds: [UInt64]
    public let jitterFraction: Double
    public let stableConnectionNanoseconds: UInt64

    public init(
        delaysNanoseconds: [UInt64] = [
            1_000_000_000,
            2_000_000_000,
            4_000_000_000,
            8_000_000_000,
            16_000_000_000,
            30_000_000_000,
            60_000_000_000,
        ],
        jitterFraction: Double = 0.1,
        stableConnectionNanoseconds: UInt64 = 30_000_000_000
    ) {
        precondition(!delaysNanoseconds.isEmpty)
        precondition(delaysNanoseconds.allSatisfy { $0 > 0 })
        precondition((0 ... 0.5).contains(jitterFraction))
        self.delaysNanoseconds = delaysNanoseconds
        self.jitterFraction = jitterFraction
        self.stableConnectionNanoseconds = stableConnectionNanoseconds
    }

    public func delayNanoseconds(attempt: Int, randomUnit: Double) -> UInt64 {
        let index = min(max(attempt, 0), delaysNanoseconds.count - 1)
        let base = Double(delaysNanoseconds[index])
        let unit = min(max(randomUnit, 0), 1)
        let multiplier = 1 + ((unit * 2 - 1) * jitterFraction)
        return UInt64(max(1, base * multiplier))
    }
}

public protocol CodexUsageServing: Sendable {
    func start() async
    func stop() async
    func refresh() async
    func states() async -> AsyncStream<CodexUsageState>
}

public typealias JSONRPCClientFactory = @Sendable (URL) -> JSONRPCClient

public actor CodexUsageService: CodexUsageServing {
    private let applicationVersion: String
    private let locator: any CodexExecutableLocating
    private let versionInspector: any CodexVersionInspecting
    private let clientFactory: JSONRPCClientFactory
    private let clock: any BridgeClock
    private let refreshPolicy: RefreshPolicy
    private let reconnectPolicy: ReconnectPolicy
    private let randomUnit: @Sendable () -> Double
    private let logger = Logger(
        subsystem: "io.github.jianshicodes.PetHalo",
        category: "codex-bridge"
    )

    private let stateStream: AsyncStream<CodexUsageState>
    private let stateContinuation: AsyncStream<CodexUsageState>.Continuation
    private var currentState = CodexUsageState.stopped

    private var started = false
    private var stopping = false
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    private var client: JSONRPCClient?
    private var connectionGeneration = 0
    private var connectedAtNanoseconds: UInt64?
    private var reconnectAttempt = 0
    private var refreshInProgress = false

    private var eventTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var compatibility: ProtocolCompatibilityState = .unknown
    private var latestBuckets: [RateLimitBucket] = []
    private var hasRateLimitSnapshot = false
    private var latestAccountUsage: AccountUsage?
    private var authenticationAvailable: Bool?
    private var lastSuccessfulRefresh: Date?

    public init(
        applicationVersion: String,
        locator: any CodexExecutableLocating = CodexExecutableLocator(),
        versionInspector: any CodexVersionInspecting = CodexVersionInspector(),
        clientFactory: @escaping JSONRPCClientFactory = { executableURL in
            JSONRPCClient(transport: CodexAppServerProcess(executableURL: executableURL))
        },
        clock: any BridgeClock = SystemBridgeClock(),
        refreshPolicy: RefreshPolicy = RefreshPolicy(),
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy(),
        randomUnit: @escaping @Sendable () -> Double = { Double.random(in: 0 ... 1) }
    ) {
        self.applicationVersion = applicationVersion
        self.locator = locator
        self.versionInspector = versionInspector
        self.clientFactory = clientFactory
        self.clock = clock
        self.refreshPolicy = refreshPolicy
        self.reconnectPolicy = reconnectPolicy
        self.randomUnit = randomUnit
        let pair = AsyncStream.makeStream(
            of: CodexUsageState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        stateStream = pair.stream
        stateContinuation = pair.continuation
        stateContinuation.yield(.stopped)
    }

    public func states() -> AsyncStream<CodexUsageState> {
        stateStream
    }

    public func start() async {
        guard !started, !stopping else { return }
        started = true
        publish(
            connection: .starting,
            freshness: currentState.snapshot == nil ? .unavailable : .stale,
            failure: nil
        )
        logger.info("Codex bridge starting")
        await establishConnection()
    }

    public func stop() async {
        if stopping {
            await withCheckedContinuation { continuation in
                stopWaiters.append(continuation)
            }
            return
        }
        guard started || client != nil || currentState.connection != .stopped else { return }
        stopping = true
        defer {
            stopping = false
            let waiters = stopWaiters
            stopWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        started = false
        reconnectTask?.cancel()
        reconnectTask = nil
        periodicTask?.cancel()
        periodicTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        eventTask?.cancel()
        eventTask = nil
        refreshInProgress = false
        connectionGeneration += 1

        let activeClient = client
        client = nil
        if let activeClient {
            await activeClient.close()
        }
        connectedAtNanoseconds = nil
        publish(
            connection: .stopped,
            freshness: currentState.snapshot == nil ? .unavailable : .stale,
            failure: nil
        )
        logger.info("Codex bridge stopped")
    }

    public func refresh() async {
        guard started, !stopping, client != nil else { return }
        await performRefresh(includeAccountRead: true, includeUsage: true)
    }

    func stateForTesting() -> CodexUsageState {
        currentState
    }

    private func establishConnection() async {
        guard started, !stopping, client == nil else { return }

        let executableURL: URL
        switch await locator.locate() {
        case let .available(url):
            executableURL = url
        case .unavailable:
            publishUnavailable(failure: .executableMissing)
            return
        }

        let version: String
        switch await versionInspector.inspect(executableURL: executableURL) {
        case let .available(value):
            version = value
        case .unavailable:
            publishUnavailable(failure: .versionInspectionFailed)
            return
        }

        guard CodexCompatibilityRegistry.compatibility(for: version) != nil else {
            compatibility = .unsupported(version: version)
            publishUnavailable(failure: .unsupportedProtocolVersion)
            return
        }
        compatibility = .supported(version: version)

        let newClient = clientFactory(executableURL)
        client = newClient
        connectionGeneration += 1
        let generation = connectionGeneration

        do {
            try await newClient.start()
        } catch {
            await connectionFailed(
                generation: generation,
                client: newClient,
                failure: .processLaunchFailed
            )
            return
        }

        let events = await newClient.events()
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                await self.handle(event: event, generation: generation)
            }
        }

        do {
            _ = try await newClient.request(.initialize, params: initializeParameters())
            try await newClient.notify(.initialized)
        } catch {
            await connectionFailed(
                generation: generation,
                client: newClient,
                failure: safeFailure(for: error)
            )
            return
        }

        guard generation == connectionGeneration, client != nil, !stopping else {
            await newClient.close()
            return
        }
        connectedAtNanoseconds = clock.monotonicNanoseconds()
        logger.info("Codex bridge handshake completed")
        await performRefresh(includeAccountRead: true, includeUsage: true)
        guard generation == connectionGeneration, client != nil, !stopping else { return }
        schedulePeriodicRefresh()
    }

    private func initializeParameters() -> JSONValue {
        .object([
            "clientInfo": .object([
                "name": .string("pet_halo"),
                "title": .string("Pet Halo"),
                "version": .string(applicationVersion),
            ]),
            "capabilities": .object([
                "experimentalApi": .bool(true),
                "requestAttestation": .bool(false),
            ]),
        ])
    }

    private func performRefresh(includeAccountRead: Bool, includeUsage: Bool) async {
        guard !refreshInProgress, let activeClient = client, !stopping else { return }
        refreshInProgress = true
        defer { refreshInProgress = false }
        let generation = connectionGeneration

        var failure: SafeFailureReason?
        var successfulComponent = false
        var retainedStaleComponent = false

        if includeAccountRead {
            do {
                let value = try await activeClient.request(
                    .accountRead,
                    params: .object(["refreshToken": .bool(false)])
                )
                let account = try CodexDTOCodec.decode(AccountAvailabilityDTO.self, from: value)
                authenticationAvailable = account.accountAvailable || !account.requiresOpenAIAuthentication
                if authenticationAvailable == false {
                    failure = .authenticationUnavailable
                }
            } catch {
                if shouldReconnect(for: error, timeoutIsFatal: false) {
                    await connectionFailed(
                        generation: generation,
                        client: activeClient,
                        failure: safeFailure(for: error)
                    )
                    return
                }
                failure = safeFailure(for: error)
            }
        }

        do {
            let value = try await activeClient.request(.rateLimitsRead)
            let response = try CodexDTOCodec.decode(RateLimitsResponseDTO.self, from: value)
            latestBuckets = CodexUsageNormalizer.rateLimitBuckets(from: response)
            hasRateLimitSnapshot = true
            successfulComponent = true
        } catch {
            if shouldReconnect(for: error) {
                await connectionFailed(
                    generation: generation,
                    client: activeClient,
                    failure: safeFailure(for: error)
                )
                return
            }
            retainedStaleComponent = hasRateLimitSnapshot
            failure = failure ?? rateLimitFailure(for: error)
        }

        if includeUsage {
            do {
                let value = try await activeClient.request(.accountUsageRead)
                let response = try CodexDTOCodec.decode(AccountUsageResponseDTO.self, from: value)
                latestAccountUsage = try CodexUsageNormalizer.accountUsage(from: response)
                successfulComponent = true
            } catch {
                if shouldReconnect(for: error, timeoutIsFatal: false) {
                    await connectionFailed(
                        generation: generation,
                        client: activeClient,
                        failure: safeFailure(for: error)
                    )
                    return
                }
                retainedStaleComponent = retainedStaleComponent || latestAccountUsage != nil
                failure = failure ?? accountUsageFailure(for: error)
            }
        }

        guard generation == connectionGeneration, client != nil, !stopping else { return }
        if successfulComponent {
            lastSuccessfulRefresh = clock.dateNow()
        }
        let snapshot = makeSnapshot()
        let freshness: DataFreshness
        if retainedStaleComponent {
            freshness = .stale
        } else if successfulComponent {
            freshness = .current
        } else {
            freshness = snapshot == nil ? .unavailable : .stale
        }
        publish(connection: .connected, freshness: freshness, failure: failure)
    }

    private func makeSnapshot() -> UsageSnapshot? {
        guard hasRateLimitSnapshot || latestAccountUsage != nil else { return nil }
        return UsageSnapshot(
            rateLimitBuckets: latestBuckets,
            accountUsage: latestAccountUsage,
            contextUsage: nil,
            collectedAt: lastSuccessfulRefresh ?? clock.dateNow()
        )
    }

    private func makeCapabilities() -> UsageCapabilities {
        let weekly: Capability<QuotaWindow>
        let fiveHour: Capability<QuotaWindow>
        if hasRateLimitSnapshot {
            weekly = UsageSemantics.window(
                durationMinutes: UsageSemantics.weeklyMinutes,
                in: latestBuckets
            )
            fiveHour = UsageSemantics.window(
                durationMinutes: UsageSemantics.fiveHourMinutes,
                in: latestBuckets
            )
        } else {
            weekly = .unavailable(.requestFailed)
            fiveHour = .unavailable(.requestFailed)
        }

        let accountCapability: Capability<AccountUsage>
        if let latestAccountUsage {
            accountCapability = .available(latestAccountUsage)
        } else if authenticationAvailable == false {
            accountCapability = .unavailable(.authenticationUnavailable)
        } else {
            accountCapability = .unavailable(.requestFailed)
        }
        return UsageCapabilities(
            generalWeekly: weekly,
            generalFiveHour: fiveHour,
            accountUsage: accountCapability,
            contextUsage: .unavailable(.unsupported)
        )
    }

    private func schedulePeriodicRefresh() {
        guard periodicTask == nil, !stopping else { return }
        let rateInterval = refreshPolicy.rateLimitsNanoseconds
        let usageInterval = refreshPolicy.accountUsageNanoseconds
        let clock = self.clock
        periodicTask = Task { [weak self, clock] in
            let start = clock.monotonicNanoseconds()
            var nextRate = start &+ rateInterval
            var nextUsage = start &+ usageInterval

            while !Task.isCancelled {
                let next = min(nextRate, nextUsage)
                let now = clock.monotonicNanoseconds()
                if next > now {
                    do {
                        try await clock.sleep(nanoseconds: next - now)
                    } catch {
                        return
                    }
                }
                if Task.isCancelled { return }
                let current = clock.monotonicNanoseconds()
                let includeUsage = current >= nextUsage
                while nextRate <= current {
                    nextRate &+= rateInterval
                }
                while nextUsage <= current {
                    nextUsage &+= usageInterval
                }
                guard let self else { return }
                await self.performRefresh(includeAccountRead: false, includeUsage: includeUsage)
            }
        }
    }

    private func scheduleNotificationRefresh() {
        debounceTask?.cancel()
        let delay = refreshPolicy.notificationDebounceNanoseconds
        let clock = self.clock
        debounceTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self else { return }
            await self.clearDebounceTaskAndRefresh()
        }
    }

    private func clearDebounceTaskAndRefresh() async {
        debounceTask = nil
        await performRefresh(includeAccountRead: false, includeUsage: false)
    }

    private func handle(event: JSONRPCEvent, generation: Int) async {
        guard generation == connectionGeneration, !stopping else { return }
        switch event {
        case let .notification(method, _):
            if method == "account/rateLimits/updated" || method == "account/updated" {
                scheduleNotificationRefresh()
            }
        case let .disconnected(error):
            await connectionFailed(
                generation: generation,
                client: client,
                failure: safeFailure(for: error)
            )
        }
    }

    private func connectionFailed(
        generation: Int,
        client failedClient: JSONRPCClient?,
        failure: SafeFailureReason
    ) async {
        guard generation == connectionGeneration, !stopping else { return }
        if let connectedAtNanoseconds,
           clock.monotonicNanoseconds() &- connectedAtNanoseconds >= reconnectPolicy.stableConnectionNanoseconds
        {
            reconnectAttempt = 0
        }

        connectionGeneration += 1
        connectedAtNanoseconds = nil
        periodicTask?.cancel()
        periodicTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        eventTask?.cancel()
        eventTask = nil
        client = nil
        if let failedClient {
            await failedClient.close()
        }
        publish(
            connection: .reconnecting(attempt: reconnectAttempt + 1),
            freshness: makeSnapshot() == nil ? .unavailable : .stale,
            failure: failure
        )
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil, started, !stopping else { return }
        let attempt = reconnectAttempt
        reconnectAttempt += 1
        let delay = reconnectPolicy.delayNanoseconds(
            attempt: attempt,
            randomUnit: randomUnit()
        )
        let clock = self.clock
        logger.info("Codex bridge reconnect scheduled, attempt: \(attempt + 1, privacy: .public)")
        reconnectTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self else { return }
            await self.runReconnect()
        }
    }

    private func runReconnect() async {
        reconnectTask = nil
        guard started, !stopping, client == nil else { return }
        await establishConnection()
    }

    private func publishUnavailable(failure: SafeFailureReason) {
        publish(
            connection: .unavailable,
            freshness: makeSnapshot() == nil ? .unavailable : .stale,
            failure: failure
        )
        logger.info("Codex bridge unavailable, reason: \(failure.rawValue, privacy: .public)")
    }

    private func publish(
        connection: BridgeConnectionState,
        freshness: DataFreshness,
        failure: SafeFailureReason?
    ) {
        currentState = CodexUsageState(
            connection: connection,
            compatibility: compatibility,
            snapshot: makeSnapshot(),
            capabilities: makeCapabilities(),
            freshness: freshness,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            failureReason: failure
        )
        stateContinuation.yield(currentState)
    }

    private func safeFailure(for error: Error) -> SafeFailureReason {
        guard let rpcError = error as? JSONRPCClientError else {
            return .protocolViolation
        }
        switch rpcError {
        case .requestTimedOut:
            return .requestTimedOut
        case .transportClosed, .notStarted:
            return .transportClosed
        case .cancelled:
            return .cancelled
        case .remoteError, .invalidMessage, .duplicateResponse, .encodingFailed, .alreadyStarted:
            return .protocolViolation
        }
    }

    private func rateLimitFailure(for error: Error) -> SafeFailureReason {
        if let rpcError = error as? JSONRPCClientError, rpcError == .requestTimedOut {
            return .requestTimedOut
        }
        return .rateLimitsUnavailable
    }

    private func accountUsageFailure(for error: Error) -> SafeFailureReason {
        if let rpcError = error as? JSONRPCClientError {
            if rpcError == .remoteError(code: -32_601) {
                return .accountUsageUnsupported
            }
            if rpcError == .requestTimedOut {
                return .requestTimedOut
            }
        }
        return .accountUsageUnavailable
    }

    private func shouldReconnect(for error: Error, timeoutIsFatal: Bool = true) -> Bool {
        guard let rpcError = error as? JSONRPCClientError else { return false }
        switch rpcError {
        case .transportClosed, .notStarted, .invalidMessage, .duplicateResponse:
            return true
        case .requestTimedOut:
            return timeoutIsFatal
        case .remoteError, .cancelled, .encodingFailed, .alreadyStarted:
            return false
        }
    }
}
