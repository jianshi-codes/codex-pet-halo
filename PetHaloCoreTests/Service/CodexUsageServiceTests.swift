import Foundation
import XCTest
@testable import PetHaloCore

private struct FixedLocator: CodexExecutableLocating {
    let result: CodexExecutableLocation

    func locate() async -> CodexExecutableLocation {
        result
    }
}

private struct FixedVersionInspector: CodexVersionInspecting {
    let result: CodexVersionInspection

    func inspect(executableURL: URL) async -> CodexVersionInspection {
        result
    }
}

private actor FirstDelayedLocator: CodexExecutableLocating {
    private let result: CodexExecutableLocation
    private var firstCall = true
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaiting = false

    init(result: CodexExecutableLocation) {
        self.result = result
    }

    func locate() async -> CodexExecutableLocation {
        if firstCall {
            firstCall = false
            isWaiting = true
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
            isWaiting = false
        }
        return result
    }

    func release() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}

private actor FirstDelayedVersionInspector: CodexVersionInspecting {
    private let result: CodexVersionInspection
    private var firstCall = true
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaiting = false

    init(result: CodexVersionInspection) {
        self.result = result
    }

    func inspect(executableURL: URL) async -> CodexVersionInspection {
        if firstCall {
            firstCall = false
            isWaiting = true
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
            isWaiting = false
        }
        return result
    }

    func release() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}

private final class ChildOwnershipTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var live = 0
    private var maximum = 0

    func started() {
        lock.lock()
        live += 1
        maximum = max(maximum, live)
        lock.unlock()
    }

    func stopped() {
        lock.lock()
        live -= 1
        lock.unlock()
    }

    func snapshot() -> (live: Int, maximum: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (live, maximum)
    }
}

private actor TrackingTransport: JSONRPCTransport {
    private let base: CodexAppServerProcess
    private let tracker: ChildOwnershipTracker
    private var ownsChild = false

    init(base: CodexAppServerProcess, tracker: ChildOwnershipTracker) {
        self.base = base
        self.tracker = tracker
    }

    func start() async throws {
        try await base.start()
        ownsChild = true
        tracker.started()
    }

    func send(_ data: Data) async throws {
        try await base.send(data)
    }

    func inboundMessages() async -> AsyncThrowingStream<Data, Error> {
        await base.inboundMessages()
    }

    func stop() async {
        await base.stop()
        if ownsChild {
            ownsChild = false
            tracker.stopped()
        }
    }
}

private final class ScenarioFactoryBox: @unchecked Sendable {
    private let lock = NSLock()
    private var scenarios: [String]
    private(set) var creationCount = 0
    let scriptURL: URL
    let timeoutPolicy: JSONRPCTimeoutPolicy
    let observationURL: URL?
    let tracker: ChildOwnershipTracker?

    init(
        scenarios: [String],
        scriptURL: URL,
        timeoutPolicy: JSONRPCTimeoutPolicy = JSONRPCTimeoutPolicy(),
        observationURL: URL? = nil,
        tracker: ChildOwnershipTracker? = nil
    ) {
        self.scenarios = scenarios
        self.scriptURL = scriptURL
        self.timeoutPolicy = timeoutPolicy
        self.observationURL = observationURL
        self.tracker = tracker
    }

    func makeClient(_: URL) -> JSONRPCClient {
        lock.lock()
        let index = min(creationCount, scenarios.count - 1)
        let scenario = scenarios[index]
        creationCount += 1
        lock.unlock()
        var arguments = [scriptURL.path, scenario]
        if let observationURL {
            arguments.append(observationURL.path)
        }
        let process = CodexAppServerProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: arguments,
            shutdownGraceNanoseconds: 500_000_000
        )
        let transport: any JSONRPCTransport
        if let tracker {
            transport = TrackingTransport(base: process, tracker: tracker)
        } else {
            transport = process
        }
        return JSONRPCClient(transport: transport, timeoutPolicy: timeoutPolicy)
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return creationCount
    }
}

private final class TestBridgeClock: @unchecked Sendable, BridgeClock {
    private struct Waiter {
        let deadline: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var nowNanoseconds: UInt64 = 1_000_000
    private var waiters: [UUID: Waiter] = [:]

    func dateNow() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return Date(timeIntervalSince1970: 1_700_000_000 + Double(nowNanoseconds) / 1_000_000_000)
    }

    func monotonicNanoseconds() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return nowNanoseconds
    }

    func sleep(nanoseconds: UInt64) async throws {
        let id = UUID()
        let deadline: UInt64 = {
            lock.lock()
            defer { lock.unlock() }
            return nowNanoseconds &+ nanoseconds
        }()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if nowNanoseconds >= deadline {
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters[id] = Waiter(deadline: deadline, continuation: continuation)
                    lock.unlock()
                }
            }
        } onCancel: {
            self.cancel(id: id)
        }
    }

    func advance(by nanoseconds: UInt64) {
        lock.lock()
        nowNanoseconds &+= nanoseconds
        let ready = waiters.filter { $0.value.deadline <= nowNanoseconds }
        for key in ready.keys {
            waiters.removeValue(forKey: key)
        }
        lock.unlock()
        for waiter in ready.values {
            waiter.continuation.resume()
        }
    }

    func hasWaiter(dueIn nanoseconds: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let expectedDeadline = nowNanoseconds &+ nanoseconds
        return waiters.values.contains { $0.deadline == expectedDeadline }
    }

    private func cancel(id: UUID) {
        lock.lock()
        let waiter = waiters.removeValue(forKey: id)
        lock.unlock()
        waiter?.continuation.resume(throwing: CancellationError())
    }
}

final class CodexUsageServiceTests: XCTestCase {
    func testValidInitialRefreshPublishesStableDomainAndContextUnavailable() async throws {
        let (service, _, _) = try makeService(scenarios: ["valid"])

        await service.start()
        let state = await service.stateForTesting()

        XCTAssertEqual(state.connection, .connected)
        XCTAssertEqual(state.compatibility, .supported(version: "0.145.0-alpha.18"))
        XCTAssertEqual(
            state.componentFreshness,
            UsageComponentFreshness(rateLimits: .current, accountUsage: .current)
        )
        XCTAssertEqual(state.freshness, .current)
        XCTAssertEqual(state.snapshot?.rateLimitBuckets.map(\.id), ["codex"])
        XCTAssertNil(state.snapshot?.contextUsage)
        XCTAssertEqual(
            state.capabilities.generalWeekly,
            .available(
                QuotaWindow(
                    source: .primary,
                    usedPercent: 25,
                    durationMinutes: 10_080,
                    resetsAt: nil
                )
            )
        )
        XCTAssertEqual(state.capabilities.generalFiveHour, .unavailable(.matchingWindowMissing))
        await service.stop()
    }

    func testRateLimitsRemainAvailableWhenOptionalUsageFails() async throws {
        let (service, _, _) = try makeService(scenarios: ["usage-fails"])

        await service.start()
        let state = await service.stateForTesting()

        XCTAssertEqual(state.connection, .connected)
        XCTAssertEqual(state.failureReason, .accountUsageUnsupported)
        XCTAssertNotNil(state.snapshot)
        XCTAssertNil(state.snapshot?.accountUsage)
        XCTAssertEqual(state.capabilities.accountUsage, .unavailable(.unsupported))
        XCTAssertEqual(state.componentFreshness.rateLimits, .current)
        XCTAssertEqual(state.componentFreshness.accountUsage, .unavailable)
        XCTAssertEqual(state.freshness, .current)
        await service.stop()
    }

    func testRetainedAccountUsageIsMarkedStaleWhenItsRefreshFails() async throws {
        let (service, _, _) = try makeService(scenarios: ["usage-fails-after-first"])
        await service.start()
        let initial = await service.stateForTesting()
        XCTAssertEqual(initial.freshness, .current)
        XCTAssertNotNil(initial.snapshot?.accountUsage)

        await service.refresh()
        let refreshed = await service.stateForTesting()

        XCTAssertEqual(refreshed.connection, .connected)
        XCTAssertEqual(refreshed.componentFreshness.rateLimits, .current)
        XCTAssertEqual(refreshed.componentFreshness.accountUsage, .stale)
        XCTAssertEqual(refreshed.freshness, .stale)
        XCTAssertNotNil(refreshed.snapshot?.accountUsage)
        XCTAssertEqual(refreshed.failureReason, .accountUsageUnsupported)
        await service.stop()
    }

    func testStaleAccountUsageSurvivesRateOnlyRefreshAndRecoversOnFullRefresh() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["usage-stale-then-recovers"],
            observationURL: observation
        )
        await service.start()
        let initial = await service.stateForTesting()
        let originalUsage = try XCTUnwrap(initial.snapshot?.accountUsage)
        XCTAssertEqual(initial.componentFreshness.rateLimits, .current)
        XCTAssertEqual(initial.componentFreshness.accountUsage, .current)

        await service.refresh()
        let failedUsage = await service.stateForTesting()
        XCTAssertEqual(failedUsage.componentFreshness.rateLimits, .current)
        XCTAssertEqual(failedUsage.componentFreshness.accountUsage, .stale)
        XCTAssertEqual(failedUsage.freshness, .stale)
        XCTAssertEqual(failedUsage.snapshot?.accountUsage, originalUsage)
        XCTAssertEqual(failedUsage.failureReason, .accountUsageUnsupported)
        let failedCollectionTime = failedUsage.snapshot?.collectedAt

        try await waitForClockWaiter(clock, dueIn: 60_000_000_000)
        clock.advance(by: 60_000_000_000)
        let notified = try await waitForState(service) {
            $0.componentFreshness.rateLimits == .stale
                && $0.componentFreshness.accountUsage == .stale
        }
        XCTAssertEqual(notified.snapshot?.accountUsage, originalUsage)

        let rateOnly = try await waitForState(service) {
            $0.componentFreshness.rateLimits == .current
                && $0.componentFreshness.accountUsage == .stale
                && $0.snapshot?.collectedAt != failedCollectionTime
        }
        XCTAssertEqual(rateOnly.freshness, .stale)
        XCTAssertEqual(rateOnly.snapshot?.accountUsage, originalUsage)
        XCTAssertEqual(rateOnly.failureReason, .accountUsageUnsupported)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)

        await service.refresh()
        let recovered = await service.stateForTesting()
        XCTAssertEqual(recovered.componentFreshness.rateLimits, .current)
        XCTAssertEqual(recovered.componentFreshness.accountUsage, .current)
        XCTAssertEqual(recovered.freshness, .current)
        XCTAssertNil(recovered.failureReason)
        XCTAssertNotEqual(recovered.snapshot?.accountUsage, originalUsage)
        XCTAssertEqual(recovered.snapshot?.accountUsage?.dailyBuckets?.first?.tokenCount, 99)
        await service.stop()
    }

    func testOptionalAccountUsageTimeoutDoesNotDisconnectValidRateLimits() async throws {
        let (service, _, _) = try makeService(
            scenarios: ["usage-delayed"],
            timeoutPolicy: JSONRPCTimeoutPolicy(
                initialize: .seconds(1),
                normal: .milliseconds(50)
            )
        )

        await service.start()
        let state = await service.stateForTesting()

        XCTAssertEqual(state.connection, .connected)
        XCTAssertEqual(state.failureReason, .requestTimedOut)
        XCTAssertNotNil(state.snapshot)
        XCTAssertNil(state.snapshot?.accountUsage)
        XCTAssertEqual(state.componentFreshness.rateLimits, .current)
        XCTAssertEqual(state.componentFreshness.accountUsage, .unavailable)
        XCTAssertEqual(state.freshness, .current)
        await service.stop()
    }

    func testAuthenticationUnavailableIsDistinctFromTransportFailure() async throws {
        let (service, _, _) = try makeService(scenarios: ["auth-unavailable"])

        await service.start()
        let state = await service.stateForTesting()

        XCTAssertEqual(state.connection, .connected)
        XCTAssertEqual(state.failureReason, .authenticationUnavailable)
        XCTAssertNotEqual(state.failureReason, .transportClosed)
        XCTAssertEqual(state.componentFreshness, .unavailable)
        await service.stop()
    }

    func testSparseNotificationBurstDebouncesToOneCompleteRefreshSeam() async throws {
        let (service, clock, _) = try makeService(scenarios: ["burst"])
        await service.start()
        let before = await service.stateForTesting().lastSuccessfulRefresh

        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        clock.advance(by: 250_000_000)
        let after = try await waitForState(service) { state in
            state.lastSuccessfulRefresh != before
        }

        XCTAssertEqual(after.connection, .connected)
        XCTAssertEqual(after.snapshot?.rateLimitBuckets.count, 1)
        await service.stop()
    }

    func testCrashReconnectsWithBackoffAndIntentionalStopPreventsAnotherLaunch() async throws {
        let (service, clock, factory) = try makeService(scenarios: ["abrupt", "valid"])
        await service.start()
        let reconnectingState = try await waitForState(service) {
            $0.connection == .reconnecting(attempt: 1)
        }
        XCTAssertEqual(reconnectingState.connection, .reconnecting(attempt: 1))
        XCTAssertEqual(reconnectingState.componentFreshness, .unavailable)
        XCTAssertEqual(factory.count(), 1)

        try await waitForClockWaiter(clock, dueIn: 1_000_000_000)
        clock.advance(by: 1_000_000_000)
        let connected = try await waitForState(service) { $0.connection == .connected }
        XCTAssertEqual(connected.connection, .connected)
        XCTAssertEqual(factory.count(), 2)

        await service.stop()
        clock.advance(by: 60_000_000_000)
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(factory.count(), 2)
        let stoppedState = await service.stateForTesting()
        XCTAssertEqual(stoppedState.connection, .stopped)
        XCTAssertEqual(stoppedState.componentFreshness, .unavailable)
    }

    func testUnsupportedVersionAndMissingExecutableNeverLaunchProcess() async throws {
        let script = try fixtureURL()
        let unsupportedFactory = ScenarioFactoryBox(scenarios: ["valid"], scriptURL: script)
        let unsupported = CodexUsageService(
            applicationVersion: "test",
            locator: FixedLocator(result: .available(URL(fileURLWithPath: "/usr/bin/python3"))),
            versionInspector: FixedVersionInspector(result: .available("9.9.9")),
            clientFactory: unsupportedFactory.makeClient,
            clock: TestBridgeClock(),
            randomUnit: { 0.5 }
        )
        await unsupported.start()
        let unsupportedState = await unsupported.stateForTesting()
        XCTAssertEqual(unsupportedState.failureReason, .unsupportedProtocolVersion)
        XCTAssertEqual(unsupportedFactory.count(), 0)

        let missingFactory = ScenarioFactoryBox(scenarios: ["valid"], scriptURL: script)
        let missing = CodexUsageService(
            applicationVersion: "test",
            locator: FixedLocator(result: .unavailable),
            versionInspector: FixedVersionInspector(result: .available("0.145.0-alpha.18")),
            clientFactory: missingFactory.makeClient,
            clock: TestBridgeClock(),
            randomUnit: { 0.5 }
        )
        await missing.start()
        let missingState = await missing.stateForTesting()
        XCTAssertEqual(missingState.failureReason, .executableMissing)
        XCTAssertEqual(missingFactory.count(), 0)
    }

    func testRepeatedStartAndStopAreIdempotent() async throws {
        let (service, _, factory) = try makeService(scenarios: ["valid"])
        await service.start()
        await service.start()
        XCTAssertEqual(factory.count(), 1)
        await service.stop()
        await service.stop()
        let stoppedState = await service.stateForTesting()
        XCTAssertEqual(stoppedState.connection, .stopped)
    }

    func testStopDuringDelayedLocatorCannotResurrectConnectionAndFreshStartIsIndependent() async throws {
        let locator = FirstDelayedLocator(
            result: .available(URL(fileURLWithPath: "/usr/bin/python3"))
        )
        let factory = ScenarioFactoryBox(scenarios: ["valid"], scriptURL: try fixtureURL())
        let service = makeService(locator: locator, factory: factory)
        let firstStart = Task { await service.start() }
        try await waitUntil { await locator.isWaiting }

        let stop = Task { await service.stop() }
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(factory.count(), 0)
        await locator.release()
        await stop.value
        await firstStart.value

        let stopped = await service.stateForTesting()
        XCTAssertEqual(stopped.connection, .stopped)
        XCTAssertEqual(factory.count(), 0)

        await service.start()
        let restarted = await service.stateForTesting()
        XCTAssertEqual(restarted.connection, .connected)
        XCTAssertEqual(factory.count(), 1)
        await service.stop()
    }

    func testStopDuringDelayedVersionInspectionNeverLaunchesOrOverwritesStopped() async throws {
        let inspector = FirstDelayedVersionInspector(result: .available("0.145.0-alpha.18"))
        let factory = ScenarioFactoryBox(scenarios: ["valid"], scriptURL: try fixtureURL())
        let service = makeService(versionInspector: inspector, factory: factory)
        let start = Task { await service.start() }
        try await waitUntil { await inspector.isWaiting }

        let stop = Task { await service.stop() }
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(factory.count(), 0)
        await inspector.release()
        await stop.value
        await start.value

        let state = await service.stateForTesting()
        XCTAssertEqual(state.connection, .stopped)
        XCTAssertEqual(factory.count(), 0)
    }

    func testAccountUpdateImmediatelyQuarantinesOldDataThenLogoutClearsAllCapabilities() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["account-logout"],
            observationURL: observation
        )
        await service.start()
        let invalidated = try await waitForState(service) {
            $0.connection == .connected && $0.freshness == .unavailable && $0.snapshot == nil
        }
        XCTAssertEqual(invalidated.capabilities.accountUsage, .unavailable(.requestFailed))
        XCTAssertEqual(invalidated.componentFreshness, .unavailable)

        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        clock.advance(by: 250_000_000)
        let loggedOut = try await waitForState(service) {
            $0.failureReason == .authenticationUnavailable
        }
        XCTAssertNil(loggedOut.snapshot)
        XCTAssertEqual(loggedOut.capabilities.generalWeekly, .unavailable(.requestFailed))
        XCTAssertEqual(loggedOut.capabilities.generalFiveHour, .unavailable(.requestFailed))
        XCTAssertEqual(loggedOut.capabilities.accountUsage, .unavailable(.authenticationUnavailable))
        XCTAssertEqual(loggedOut.componentFreshness, .unavailable)
        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)
        await service.stop()
    }

    func testAccountUpdateDuringInitialRefreshQueuesOneFullFollowUp() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["account-update-during-initial"],
            observationURL: observation
        )
        await service.start()
        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        clock.advance(by: 250_000_000)
        try await waitForMethodCount(1, method: "account/usage/read", in: observation)
        _ = try await waitForState(service) { $0.snapshot != nil }

        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 1)
        let state = await service.stateForTesting()
        XCTAssertEqual(state.connection, .connected)
        XCTAssertNotNil(state.snapshot)
        await service.stop()
    }

    func testAccountUpdateAndRateBurstCoalesceToOneStrongestFullRefresh() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["account-update-burst"],
            observationURL: observation
        )
        await service.start()
        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        clock.advance(by: 250_000_000)
        try await waitForMethodCount(2, method: "account/usage/read", in: observation)

        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)
        await service.stop()
    }

    func testAccountSwitchNeverPresentsPreviousUsageAsAvailable() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["account-switch"],
            observationURL: observation
        )
        await service.start()
        let quarantined = try await waitForState(service) {
            $0.freshness == .unavailable && $0.snapshot == nil
        }
        XCTAssertEqual(quarantined.capabilities.accountUsage, .unavailable(.requestFailed))
        XCTAssertEqual(quarantined.componentFreshness, .unavailable)

        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        clock.advance(by: 250_000_000)
        try await waitForMethodCount(2, method: "account/usage/read", in: observation)
        let switched = try await waitForState(service) { state in
            guard case let .available(usage) = state.capabilities.accountUsage else {
                return false
            }
            return usage.dailyBuckets?.first?.tokenCount == 99
        }
        guard case let .available(usage) = switched.capabilities.accountUsage else {
            XCTFail("Expected refreshed account usage")
            await service.stop()
            return
        }
        XCTAssertEqual(usage.dailyBuckets?.first?.tokenCount, 99)
        await service.stop()
    }

    func testRateNotificationDuringRefreshRunsExactlyOneRateOnlyFollowUp() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["rate-notification-during-refresh"],
            observationURL: observation
        )
        await service.start()
        let refresh = Task { await service.refresh() }
        try await waitForClockWaiter(clock, dueIn: 250_000_000)
        let invalidated = try await waitForState(service) {
            $0.componentFreshness.rateLimits == .stale
                && $0.componentFreshness.accountUsage == .current
        }
        XCTAssertEqual(invalidated.freshness, .stale)
        clock.advance(by: 250_000_000)
        await refresh.value
        try await waitForMethodCount(3, method: "account/rateLimits/read", in: observation)

        let restored = try await waitForState(service) {
            $0.componentFreshness.rateLimits == .current
                && $0.componentFreshness.accountUsage == .current
        }
        XCTAssertEqual(restored.freshness, .current)

        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 3)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)
        await service.stop()
    }

    func testManualRefreshDuringPeriodicReadCoalescesWithoutOverlap() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["rate-delayed-after-first"],
            observationURL: observation
        )
        await service.start()
        try await waitForClockWaiter(clock, dueIn: 60_000_000_000)
        clock.advance(by: 60_000_000_000)
        try await waitForMethodCount(2, method: "account/rateLimits/read", in: observation)
        await service.refresh()
        try await waitForMethodCount(2, method: "account/usage/read", in: observation)

        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 3)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)
        await service.stop()
    }

    func testStopCancelsDebouncedRefreshQueue() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["burst"],
            observationURL: observation
        )
        await service.start()
        try await waitForClockWaiter(clock, dueIn: 250_000_000)

        await service.stop()
        clock.advance(by: 250_000_000)
        for _ in 0 ..< 20 { await Task.yield() }
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 1)
        let state = await service.stateForTesting()
        XCTAssertEqual(state.connection, .stopped)
    }

    func testOldGenerationQueuedRefreshCannotRunOnReplacementConnection() async throws {
        let observation = try makeObservationFile()
        defer { try? FileManager.default.removeItem(at: observation.deletingLastPathComponent()) }
        let (service, clock, _) = try makeService(
            scenarios: ["queued-then-abrupt", "valid"],
            observationURL: observation
        )
        await service.start()
        _ = try await waitForState(service) { $0.connection == .reconnecting(attempt: 1) }
        try await waitForClockWaiter(clock, dueIn: 1_000_000_000)
        clock.advance(by: 1_000_000_000)
        _ = try await waitForState(service) { $0.connection == .connected }

        clock.advance(by: 250_000_000)
        for _ in 0 ..< 50 { await Task.yield() }
        XCTAssertEqual(try methodCount("account/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/rateLimits/read", in: observation), 2)
        XCTAssertEqual(try methodCount("account/usage/read", in: observation), 2)
        await service.stop()
    }

    func testInvalidMessageCleanupPrecedesReconnectAndMaximumOwnedChildrenIsOne() async throws {
        let tracker = ChildOwnershipTracker()
        let clock = TestBridgeClock()
        let factory = ScenarioFactoryBox(
            scenarios: ["invalid-delayed-termination", "valid"],
            scriptURL: try fixtureURL(),
            tracker: tracker
        )
        let service = makeService(clock: clock, factory: factory)
        await service.start()
        let afterCleanup = tracker.snapshot()
        XCTAssertEqual(afterCleanup.live, 0)
        XCTAssertEqual(afterCleanup.maximum, 1)
        let reconnecting = await service.stateForTesting()
        XCTAssertEqual(reconnecting.connection, .reconnecting(attempt: 1))

        try await waitForClockWaiter(clock, dueIn: 1_000_000_000)
        clock.advance(by: 1_000_000_000)
        _ = try await waitForState(service) { $0.connection == .connected }
        let connected = tracker.snapshot()
        XCTAssertEqual(connected.live, 1)
        XCTAssertEqual(connected.maximum, 1)
        await service.stop()
        XCTAssertEqual(tracker.snapshot().live, 0)
    }

    func testUnexpectedDisconnectCleanupAlsoKeepsMaximumOwnedChildrenAtOne() async throws {
        let tracker = ChildOwnershipTracker()
        let clock = TestBridgeClock()
        let factory = ScenarioFactoryBox(
            scenarios: ["abrupt", "valid"],
            scriptURL: try fixtureURL(),
            tracker: tracker
        )
        let service = makeService(clock: clock, factory: factory)
        await service.start()
        _ = try await waitForState(service) { $0.connection == .reconnecting(attempt: 1) }
        XCTAssertEqual(tracker.snapshot().maximum, 1)

        try await waitForClockWaiter(clock, dueIn: 1_000_000_000)
        clock.advance(by: 1_000_000_000)
        _ = try await waitForState(service) { $0.connection == .connected }
        XCTAssertEqual(tracker.snapshot().maximum, 1)
        await service.stop()
        XCTAssertEqual(tracker.snapshot().live, 0)
    }

    private func makeService(
        scenarios: [String],
        timeoutPolicy: JSONRPCTimeoutPolicy = JSONRPCTimeoutPolicy(),
        observationURL: URL? = nil
    ) throws -> (CodexUsageService, TestBridgeClock, ScenarioFactoryBox) {
        let clock = TestBridgeClock()
        let factory = ScenarioFactoryBox(
            scenarios: scenarios,
            scriptURL: try fixtureURL(),
            timeoutPolicy: timeoutPolicy,
            observationURL: observationURL
        )
        let service = CodexUsageService(
            applicationVersion: "test",
            locator: FixedLocator(result: .available(URL(fileURLWithPath: "/usr/bin/python3"))),
            versionInspector: FixedVersionInspector(result: .available("0.145.0-alpha.18")),
            clientFactory: factory.makeClient,
            clock: clock,
            refreshPolicy: RefreshPolicy(
                rateLimitsNanoseconds: 60_000_000_000,
                accountUsageNanoseconds: 900_000_000_000,
                notificationDebounceNanoseconds: 250_000_000
            ),
            reconnectPolicy: ReconnectPolicy(jitterFraction: 0),
            randomUnit: { 0.5 }
        )
        return (service, clock, factory)
    }

    private func makeService(
        locator: any CodexExecutableLocating = FixedLocator(
            result: .available(URL(fileURLWithPath: "/usr/bin/python3"))
        ),
        versionInspector: any CodexVersionInspecting = FixedVersionInspector(
            result: .available("0.145.0-alpha.18")
        ),
        clock: TestBridgeClock = TestBridgeClock(),
        factory: ScenarioFactoryBox
    ) -> CodexUsageService {
        CodexUsageService(
            applicationVersion: "test",
            locator: locator,
            versionInspector: versionInspector,
            clientFactory: factory.makeClient,
            clock: clock,
            refreshPolicy: RefreshPolicy(
                rateLimitsNanoseconds: 60_000_000_000,
                accountUsageNanoseconds: 900_000_000_000,
                notificationDebounceNanoseconds: 250_000_000
            ),
            reconnectPolicy: ReconnectPolicy(jitterFraction: 0),
            randomUnit: { 0.5 }
        )
    }

    private func fixtureURL() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fake_app_server", withExtension: "py"))
    }

    private func waitForState(
        _ service: CodexUsageService,
        matching predicate: (CodexUsageState) -> Bool
    ) async throws -> CodexUsageState {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            let state = await service.stateForTesting()
            if predicate(state) {
                return state
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func waitForClockWaiter(
        _ clock: TestBridgeClock,
        dueIn nanoseconds: UInt64
    ) async throws {
        let continuousClock = ContinuousClock()
        let deadline = continuousClock.now.advanced(by: .seconds(10))
        while continuousClock.now < deadline {
            if clock.hasWaiter(dueIn: nanoseconds) {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func waitUntil(_ predicate: @escaping () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            if await predicate() {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func makeObservationFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("requests.log")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data()))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    private func methodCount(_ method: String, in observation: URL) throws -> Int {
        let contents = try String(contentsOf: observation, encoding: .utf8)
        return contents.split(separator: "\n").filter { $0 == Substring(method) }.count
    }

    private func waitForMethodCount(
        _ count: Int,
        method: String,
        in observation: URL
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            if try methodCount(method, in: observation) >= count {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw JSONRPCClientError.requestTimedOut
    }
}
