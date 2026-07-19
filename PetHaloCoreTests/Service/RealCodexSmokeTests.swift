import Foundation
import XCTest
@testable import PetHaloCore

final class RealCodexSmokeTests: XCTestCase {
    func testReadOnlyLocalIntegration() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/pet-halo-m2-real-smoke-enabled") else {
            throw XCTSkip("Real authenticated Codex smoke is local-only")
        }

        let service = CodexUsageService(applicationVersion: "0.1.0")
        await service.start()
        let state = await service.stateForTesting()

        guard state.connection == .connected else {
            await service.stop()
            XCTFail("M2 smoke blocker: \(typedBlocker(for: state.failureReason))")
            return
        }

        print("Codex located: yes")
        print("Protocol version: supported")
        print("Handshake: pass")
        print("Rate-limit buckets: \(state.snapshot?.rateLimitBuckets.isEmpty == false ? "available" : "unavailable")")
        print("Weekly capability: \(availability(state.capabilities.generalWeekly))")
        print("Five-hour capability: \(availability(state.capabilities.generalFiveHour))")
        print("Account Usage capability: \(availability(state.capabilities.accountUsage))")

        await service.stop()
        let stopped = await service.stateForTesting()
        XCTAssertEqual(stopped.connection, .stopped)
        XCTAssertFalse(try hasOwnedAppServerChild())
        print("Shutdown: clean")
    }

    private func availability<Value: Equatable & Sendable>(_ capability: Capability<Value>) -> String {
        if case .available = capability {
            return "available"
        }
        return "unavailable"
    }

    private func typedBlocker(for failure: SafeFailureReason?) -> String {
        switch failure {
        case .executableMissing:
            return "BLOCKED — CODEX EXECUTABLE NOT DISCOVERABLE"
        case .unsupportedProtocolVersion:
            return "BLOCKED — UNSUPPORTED CODEX PROTOCOL VERSION"
        case .authenticationUnavailable:
            return "BLOCKED — LOCAL AUTHENTICATION REQUIRED"
        default:
            return "BLOCKED — RUNTIME INTEGRATION FAILURE"
        }
    }

    private func hasOwnedAppServerChild() throws -> Bool {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(ProcessInfo.processInfo.processIdentifier), "-f", "codex.*app-server"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
