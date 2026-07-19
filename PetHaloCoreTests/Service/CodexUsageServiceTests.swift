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

private final class ScenarioFactoryBox: @unchecked Sendable {
    private let lock = NSLock()
    private var scenarios: [String]
    private(set) var creationCount = 0
    let scriptURL: URL
    let timeoutPolicy: JSONRPCTimeoutPolicy

    init(
        scenarios: [String],
        scriptURL: URL,
        timeoutPolicy: JSONRPCTimeoutPolicy = JSONRPCTimeoutPolicy()
    ) {
        self.scenarios = scenarios
        self.scriptURL = scriptURL
        self.timeoutPolicy = timeoutPolicy
    }

    func makeClient(_: URL) -> JSONRPCClient {
        lock.lock()
        let index = min(creationCount, scenarios.count - 1)
        let scenario = scenarios[index]
        creationCount += 1
        lock.unlock()
        let transport = CodexAppServerProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [scriptURL.path, scenario],
            shutdownGraceNanoseconds: 500_000_000
        )
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
        XCTAssertEqual(state.capabilities.accountUsage, .unavailable(.requestFailed))
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
        XCTAssertEqual(refreshed.freshness, .stale)
        XCTAssertNotNil(refreshed.snapshot?.accountUsage)
        XCTAssertEqual(refreshed.failureReason, .accountUsageUnsupported)
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
        XCTAssertEqual(factory.count(), 1)

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

    private func makeService(
        scenarios: [String],
        timeoutPolicy: JSONRPCTimeoutPolicy = JSONRPCTimeoutPolicy()
    ) throws -> (CodexUsageService, TestBridgeClock, ScenarioFactoryBox) {
        let clock = TestBridgeClock()
        let factory = ScenarioFactoryBox(
            scenarios: scenarios,
            scriptURL: try fixtureURL(),
            timeoutPolicy: timeoutPolicy
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

    private func fixtureURL() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "fake_app_server", withExtension: "py"))
    }

    private func waitForState(
        _ service: CodexUsageService,
        matching predicate: (CodexUsageState) -> Bool
    ) async throws -> CodexUsageState {
        for _ in 0 ..< 2_000 {
            let state = await service.stateForTesting()
            if predicate(state) {
                return state
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func waitForClockWaiter(
        _ clock: TestBridgeClock,
        dueIn nanoseconds: UInt64
    ) async throws {
        for _ in 0 ..< 2_000 {
            if clock.hasWaiter(dueIn: nanoseconds) {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw JSONRPCClientError.requestTimedOut
    }
}
