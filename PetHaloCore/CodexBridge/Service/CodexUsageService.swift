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

private enum ReleaseLaunchDiagnostic: String {
    case childStarted = "child-started"
    case executableUnavailable = "executable-unavailable"
    case versionBlocked = "version-blocked"
    case runtimeIncompatible = "runtime-incompatible"

    static func publish(_ diagnostic: Self) {
        guard let path = ProcessInfo.processInfo.environment["PET_HALO_RELEASE_SMOKE_DIAGNOSTIC_PATH"],
              !path.isEmpty
        else {
            return
        }
        try? Data((diagnostic.rawValue + "\n").utf8).write(
            to: URL(fileURLWithPath: path),
            options: .atomic
        )
    }
}

public actor CodexUsageService: CodexUsageServing {
    private enum RefreshScope: Int {
        case rateLimitsOnly
        case fullAccount

        static func strongest(_ lhs: Self?, _ rhs: Self) -> Self {
            guard let lhs else { return rhs }
            return lhs.rawValue >= rhs.rawValue ? lhs : rhs
        }
    }

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
    private var connectionAttemptEpoch = 0
    private var connectionAttemptTask: Task<Void, Never>?
    private var connectionAttemptTaskEpoch: Int?
    private var connectionGeneration = 0
    private var accountEpoch = 0
    private var connectedAtNanoseconds: UInt64?
    private var reconnectAttempt = 0
    private var refreshInProgress = false
    private var pendingRefreshScope: RefreshScope?
    private var pendingRefreshGeneration: Int?
    private var pendingNotificationScope: RefreshScope?

    private var eventTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var compatibility: ProtocolCompatibilityState = .unknown
    private var latestBuckets: [RateLimitBucket] = []
    private var hasRateLimitSnapshot = false
    private var rateLimitFreshness: DataFreshness = .unavailable
    private var latestAccountUsage: AccountUsage?
    private var accountUsageFreshness: DataFreshness = .unavailable
    private var accountUsageUnavailableReason: CapabilityUnavailableReason = .requestFailed
    private var accountUsageFailureReason: SafeFailureReason?
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
        compatibility = .unknown
        clearAccountScopedState()
        publish(
            connection: .starting,
            failure: nil
        )
        logger.info("Codex bridge starting")
        await beginConnectionAttempt()
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
        connectionAttemptEpoch += 1
        let activeAttempt = connectionAttemptTask
        activeAttempt?.cancel()
        reconnectTask?.cancel()
        reconnectTask = nil
        periodicTask?.cancel()
        periodicTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        eventTask?.cancel()
        eventTask = nil
        refreshInProgress = false
        pendingRefreshScope = nil
        pendingRefreshGeneration = nil
        pendingNotificationScope = nil
        connectionGeneration += 1

        let activeClient = client
        client = nil
        if let activeClient {
            await activeClient.close()
        }
        if let activeAttempt {
            await activeAttempt.value
        }
        connectionAttemptTask = nil
        connectionAttemptTaskEpoch = nil
        connectedAtNanoseconds = nil
        clearAccountScopedState()
        publish(
            connection: .stopped,
            failure: nil
        )
        logger.info("Codex bridge stopped")
    }

    public func refresh() async {
        guard started, !stopping else { return }
        if client != nil {
            await enqueueRefresh(scope: .fullAccount, generation: connectionGeneration)
            return
        }
        guard currentState.failureReason == .runtimeIncompatible else { return }
        compatibility = .unknown
        publish(connection: .starting, failure: nil)
        await beginConnectionAttempt()
    }

    func stateForTesting() -> CodexUsageState {
        currentState
    }

    private func beginConnectionAttempt() async {
        guard started, !stopping, client == nil, connectionAttemptTask == nil else { return }
        connectionAttemptEpoch += 1
        let epoch = connectionAttemptEpoch
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.establishConnection(epoch: epoch)
        }
        connectionAttemptTask = task
        connectionAttemptTaskEpoch = epoch
        await task.value
        if connectionAttemptTaskEpoch == epoch {
            connectionAttemptTask = nil
            connectionAttemptTaskEpoch = nil
            if case .reconnecting = currentState.connection,
               started,
               !stopping,
               client == nil,
               reconnectTask == nil
            {
                scheduleReconnect()
            }
        }
    }

    private func establishConnection(epoch: Int) async {
        guard connectionAttemptIsCurrent(epoch), client == nil else { return }

        let executableURL: URL
        switch await locator.locate() {
        case let .available(url):
            executableURL = url
        case .unavailable:
            if connectionAttemptIsCurrent(epoch) {
                ReleaseLaunchDiagnostic.publish(.executableUnavailable)
                publishUnavailable(failure: .executableMissing)
            }
            return
        }
        guard connectionAttemptIsCurrent(epoch) else { return }

        let version: String
        switch await versionInspector.inspect(executableURL: executableURL) {
        case let .available(value):
            version = value
        case .unavailable:
            if connectionAttemptIsCurrent(epoch) {
                publishUnavailable(failure: .versionInspectionFailed)
            }
            return
        }
        guard connectionAttemptIsCurrent(epoch) else { return }

        switch CodexCompatibilityPolicy.current.decision(for: version) {
        case let .reviewed(reviewed):
            compatibility = .reviewed(version: reviewed.cliVersion)
        case let .provisional(provisionalVersion):
            compatibility = .provisional(version: provisionalVersion)
        case let .blocked(blockedVersion, _):
            compatibility = .blocked(version: blockedVersion)
            ReleaseLaunchDiagnostic.publish(.versionBlocked)
            publishUnavailable(failure: .unsupportedProtocolVersion)
            return
        }

        let newClient = clientFactory(executableURL)
        guard connectionAttemptIsCurrent(epoch) else {
            await newClient.close()
            return
        }
        client = newClient
        connectionGeneration += 1
        let generation = connectionGeneration

        do {
            try await newClient.start()
            ReleaseLaunchDiagnostic.publish(.childStarted)
        } catch {
            await connectionFailed(
                generation: generation,
                client: newClient,
                failure: .processLaunchFailed
            )
            return
        }
        guard connectionAttemptIsCurrent(epoch), generation == connectionGeneration else {
            await newClient.close()
            return
        }

        let events = await newClient.events()
        guard connectionAttemptIsCurrent(epoch), generation == connectionGeneration else {
            await newClient.close()
            return
        }
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                await self.handle(event: event, generation: generation)
            }
        }

        do {
            _ = try await newClient.request(.initialize, params: initializeParameters())
            guard connectionAttemptIsCurrent(epoch), generation == connectionGeneration else {
                await newClient.close()
                return
            }
            try await newClient.notify(.initialized)
        } catch {
            await connectionFailed(
                generation: generation,
                client: newClient,
                failure: safeFailure(for: error)
            )
            return
        }

        guard connectionAttemptIsCurrent(epoch), generation == connectionGeneration, client != nil else {
            await newClient.close()
            return
        }
        connectedAtNanoseconds = clock.monotonicNanoseconds()
        logger.info("Codex bridge handshake completed")
        await enqueueRefresh(scope: .fullAccount, generation: generation)
        guard connectionAttemptIsCurrent(epoch), generation == connectionGeneration, client != nil else {
            return
        }
        schedulePeriodicRefresh()
    }

    private func connectionAttemptIsCurrent(_ epoch: Int) -> Bool {
        started && !stopping && !Task.isCancelled && epoch == connectionAttemptEpoch
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

    private func enqueueRefresh(scope: RefreshScope, generation: Int) async {
        guard generation == connectionGeneration, started, !stopping, client != nil else { return }
        if pendingRefreshGeneration != generation {
            pendingRefreshGeneration = generation
            pendingRefreshScope = scope
        } else {
            pendingRefreshScope = RefreshScope.strongest(pendingRefreshScope, scope)
        }
        guard !refreshInProgress else { return }

        refreshInProgress = true
        defer {
            refreshInProgress = false
            if pendingRefreshGeneration == generation {
                pendingRefreshGeneration = nil
                pendingRefreshScope = nil
            }
        }

        while generation == connectionGeneration,
              started,
              !stopping,
              let scope = pendingRefreshScope,
              pendingRefreshGeneration == generation
        {
            pendingRefreshScope = nil
            await performRefresh(scope: scope, generation: generation)
        }
    }

    private func performRefresh(scope: RefreshScope, generation: Int) async {
        guard generation == connectionGeneration, let activeClient = client, !stopping else { return }
        let refreshAccountEpoch = accountEpoch
        var refreshedAuthentication = authenticationAvailable
        var refreshedBuckets: [RateLimitBucket]?
        var refreshedUsage: AccountUsage?
        var refreshedUsageReason = accountUsageUnavailableReason
        var failure: SafeFailureReason?
        var successfulComponent = false
        var rateLimitReadFailed = false
        var accountUsageReadFailed = false
        var refreshedUsageFailure: SafeFailureReason?

        if scope == .fullAccount {
            do {
                let value = try await activeClient.request(
                    .accountRead,
                    params: .object(["refreshToken": .bool(false)])
                )
                guard refreshIsCurrent(generation: generation, accountEpoch: refreshAccountEpoch) else {
                    return
                }
                let account = try CodexDTOCodec.decode(AccountAvailabilityDTO.self, from: value)
                refreshedAuthentication = account.accountAvailable || !account.requiresOpenAIAuthentication
                if refreshedAuthentication == false {
                    failure = .authenticationUnavailable
                    refreshedUsageReason = .authenticationUnavailable
                }
            } catch {
                if isProvisional,
                   isRequiredProtocolIncompatibility(error)
                {
                    await runtimeIncompatible(generation: generation, client: activeClient)
                    return
                }
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
            guard refreshIsCurrent(generation: generation, accountEpoch: refreshAccountEpoch) else {
                return
            }
            let response = try CodexDTOCodec.decode(RateLimitsResponseDTO.self, from: value)
            refreshedBuckets = CodexUsageNormalizer.rateLimitBuckets(from: response)
            if isProvisional,
               !hasRequiredWeeklyCapability(refreshedBuckets ?? [])
            {
                await runtimeIncompatible(generation: generation, client: activeClient)
                return
            }
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
            if isProvisional {
                await runtimeIncompatible(generation: generation, client: activeClient)
                return
            }
            rateLimitReadFailed = true
            failure = failure ?? rateLimitFailure(for: error)
        }

        if scope == .fullAccount {
            do {
                let value = try await activeClient.request(.accountUsageRead)
                guard refreshIsCurrent(generation: generation, accountEpoch: refreshAccountEpoch) else {
                    return
                }
                let response = try CodexDTOCodec.decode(AccountUsageResponseDTO.self, from: value)
                refreshedUsage = try CodexUsageNormalizer.accountUsage(from: response)
                refreshedUsageReason = .requestFailed
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
                accountUsageReadFailed = true
                refreshedUsageFailure = accountUsageFailure(for: error)
                failure = failure ?? refreshedUsageFailure
                refreshedUsageReason = accountUsageCapabilityReason(for: error)
            }
        }

        guard refreshIsCurrent(generation: generation, accountEpoch: refreshAccountEpoch) else { return }
        authenticationAvailable = refreshedAuthentication
        if refreshedAuthentication == false {
            clearAccountScopedState()
            authenticationAvailable = false
            accountUsageUnavailableReason = .authenticationUnavailable
            publish(connection: .connected, failure: .authenticationUnavailable)
            return
        }
        if let refreshedBuckets {
            latestBuckets = refreshedBuckets
            hasRateLimitSnapshot = true
            rateLimitFreshness = .current
        } else if rateLimitReadFailed {
            rateLimitFreshness = hasRateLimitSnapshot ? .stale : .unavailable
        }
        if scope == .fullAccount {
            if let refreshedUsage {
                latestAccountUsage = refreshedUsage
                accountUsageFreshness = .current
                accountUsageFailureReason = nil
            } else if accountUsageReadFailed {
                accountUsageFreshness = latestAccountUsage == nil ? .unavailable : .stale
                accountUsageFailureReason = refreshedUsageFailure
            }
            accountUsageUnavailableReason = refreshedUsageReason
        }
        if successfulComponent {
            lastSuccessfulRefresh = clock.dateNow()
        }
        publish(
            connection: .connected,
            failure: failure
        )
    }

    private func refreshIsCurrent(generation: Int, accountEpoch: Int) -> Bool {
        generation == connectionGeneration
            && accountEpoch == self.accountEpoch
            && started
            && !stopping
            && client != nil
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
            accountCapability = .unavailable(accountUsageUnavailableReason)
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
        let generation = connectionGeneration
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
                let scope: RefreshScope = includeUsage ? .fullAccount : .rateLimitsOnly
                await self.enqueueRefresh(scope: scope, generation: generation)
            }
        }
    }

    private func scheduleNotificationRefresh(scope: RefreshScope, generation: Int) {
        guard generation == connectionGeneration, started, !stopping else { return }
        pendingNotificationScope = RefreshScope.strongest(pendingNotificationScope, scope)
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
            await self.clearDebounceTaskAndRefresh(generation: generation)
        }
    }

    private func clearDebounceTaskAndRefresh(generation: Int) async {
        debounceTask = nil
        guard generation == connectionGeneration, let scope = pendingNotificationScope else { return }
        pendingNotificationScope = nil
        await enqueueRefresh(scope: scope, generation: generation)
    }

    private func handle(event: JSONRPCEvent, generation: Int) async {
        guard generation == connectionGeneration, !stopping else { return }
        switch event {
        case let .notification(method, _):
            if method == "account/rateLimits/updated" {
                if hasRateLimitSnapshot {
                    rateLimitFreshness = .stale
                    publish(connection: .connected, failure: nil)
                }
                scheduleNotificationRefresh(scope: .rateLimitsOnly, generation: generation)
            } else if method == "account/updated" {
                clearAccountScopedState()
                publish(connection: .connected, failure: nil)
                scheduleNotificationRefresh(scope: .fullAccount, generation: generation)
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
        if isProvisional, failure == .protocolViolation {
            await runtimeIncompatible(generation: generation, client: failedClient)
            return
        }
        if let connectedAtNanoseconds,
           clock.monotonicNanoseconds() &- connectedAtNanoseconds >= reconnectPolicy.stableConnectionNanoseconds
        {
            reconnectAttempt = 0
        }

        connectionAttemptEpoch += 1
        connectionGeneration += 1
        connectedAtNanoseconds = nil
        periodicTask?.cancel()
        periodicTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        pendingNotificationScope = nil
        pendingRefreshScope = nil
        pendingRefreshGeneration = nil
        eventTask?.cancel()
        eventTask = nil
        client = nil
        if let failedClient {
            await failedClient.close()
        }
        guard started, !stopping else { return }
        clearAccountScopedState()
        publish(
            connection: .reconnecting(attempt: reconnectAttempt + 1),
            failure: failure
        )
        scheduleReconnect()
    }

    private func runtimeIncompatible(
        generation: Int,
        client failedClient: JSONRPCClient?
    ) async {
        guard generation == connectionGeneration,
              !stopping,
              case let .provisional(version) = compatibility
        else {
            return
        }

        connectionAttemptEpoch += 1
        connectionGeneration += 1
        connectedAtNanoseconds = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        periodicTask?.cancel()
        periodicTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        pendingNotificationScope = nil
        pendingRefreshScope = nil
        pendingRefreshGeneration = nil
        eventTask?.cancel()
        eventTask = nil
        client = nil
        if let failedClient {
            await failedClient.close()
        }
        guard started, !stopping else { return }
        clearAccountScopedState()
        compatibility = .runtimeIncompatible(version: version)
        ReleaseLaunchDiagnostic.publish(.runtimeIncompatible)
        publish(connection: .unavailable, failure: .runtimeIncompatible)
        logger.info(
            "Codex bridge runtime incompatible, CLI: \(version, privacy: .public)"
        )
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
        await beginConnectionAttempt()
    }

    private func publishUnavailable(failure: SafeFailureReason) {
        publish(
            connection: .unavailable,
            failure: failure
        )
        logger.info("Codex bridge unavailable, reason: \(failure.rawValue, privacy: .public)")
    }

    private func publish(
        connection: BridgeConnectionState,
        failure: SafeFailureReason?
    ) {
        currentState = CodexUsageState(
            connection: connection,
            compatibility: compatibility,
            snapshot: makeSnapshot(),
            capabilities: makeCapabilities(),
            componentFreshness: UsageComponentFreshness(
                rateLimits: rateLimitFreshness,
                accountUsage: accountUsageFreshness
            ),
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            failureReason: failure ?? accountUsageFailureReason
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

    private func accountUsageCapabilityReason(for error: Error) -> CapabilityUnavailableReason {
        if let rpcError = error as? JSONRPCClientError,
           rpcError == .remoteError(code: -32_601)
        {
            return .unsupported
        }
        if authenticationAvailable == false {
            return .authenticationUnavailable
        }
        return .requestFailed
    }

    private func clearAccountScopedState() {
        accountEpoch += 1
        latestBuckets = []
        hasRateLimitSnapshot = false
        rateLimitFreshness = .unavailable
        latestAccountUsage = nil
        accountUsageFreshness = .unavailable
        accountUsageUnavailableReason = .requestFailed
        accountUsageFailureReason = nil
        authenticationAvailable = nil
        lastSuccessfulRefresh = nil
    }

    private var isProvisional: Bool {
        if case .provisional = compatibility {
            return true
        }
        return false
    }

    private func isRequiredProtocolIncompatibility(_ error: Error) -> Bool {
        if error is CodexProtocolDecodingError {
            return true
        }
        guard let rpcError = error as? JSONRPCClientError else { return false }
        switch rpcError {
        case .invalidMessage, .duplicateResponse:
            return true
        case .remoteError(code: -32_601):
            return true
        case .notStarted, .alreadyStarted, .encodingFailed, .requestTimedOut,
             .transportClosed, .cancelled, .remoteError:
            return false
        }
    }

    private func hasRequiredWeeklyCapability(_ buckets: [RateLimitBucket]) -> Bool {
        if case .available = UsageSemantics.window(
            durationMinutes: UsageSemantics.weeklyMinutes,
            in: buckets
        ) {
            return true
        }
        return false
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
