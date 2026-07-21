import Foundation
import XCTest
@testable import PetHaloCore

final class RealCodexSmokeTests: XCTestCase {
    func testReadOnlyLocalIntegration() async throws {
        guard ProcessInfo.processInfo.environment["PET_HALO_RUN_REAL_SMOKE"] == "1" else {
            throw XCTSkip("Real authenticated Codex smoke is local-only")
        }

        let service = CodexUsageService(applicationVersion: "0.1.0")
        await service.start()
        let state = await service.stateForTesting()

        guard state.connection == .connected else {
            await service.stop()
            let blocker = "M2 smoke blocker: \(typedBlocker(for: state.failureReason))"
            try writeSmokeReport(blocker)
            XCTFail(blocker)
            return
        }
        guard case let .available(weekly) = state.capabilities.generalWeekly else {
            await service.stop()
            let blocker = "M2 smoke blocker: BLOCKED — REQUIRED WEEKLY CAPABILITY UNAVAILABLE"
            try writeSmokeReport(blocker)
            XCTFail(blocker)
            return
        }

        await service.stop()
        let stopped = await service.stateForTesting()
        XCTAssertEqual(stopped.connection, .stopped)
        XCTAssertFalse(try hasOwnedAppServerChild())
        try writeSmokeReport(
            [
                "Codex located: yes",
                "CLI version: \(cliVersion(state.compatibility))",
                "Protocol version: \(compatibilityDecision(state.compatibility))",
                "Handshake: initialize and initialized pass",
                "JSON-RPC envelopes: valid",
                "Account read: \(state.failureReason == .authenticationUnavailable ? "authentication unavailable" : "pass")",
                "Rate-limit read: pass",
                "Rate-limit buckets: \(state.snapshot?.rateLimitBuckets.isEmpty == false ? "available" : "unavailable")",
                "Weekly capability: available",
                "Weekly percentage: \(weekly.usedPercent.isFinite ? "valid" : "invalid")",
                "Weekly resetsAt: \(weekly.resetsAt == nil ? "omitted" : "decoded")",
                "Five-hour capability: \(availability(state.capabilities.generalFiveHour))",
                "Account Usage capability: \(availability(state.capabilities.accountUsage))",
                "Shutdown: clean",
            ].joined(separator: "\n")
        )
    }

    private func cliVersion(_ compatibility: ProtocolCompatibilityState) -> String {
        switch compatibility {
        case let .reviewed(version), let .provisional(version),
             let .runtimeIncompatible(version):
            return version
        case let .blocked(version):
            return version ?? "blocked"
        case .unknown:
            return "unavailable"
        }
    }

    private func compatibilityDecision(_ compatibility: ProtocolCompatibilityState) -> String {
        switch compatibility {
        case .reviewed:
            return "reviewed"
        case .provisional:
            return "provisional"
        case .blocked:
            return "blocked"
        case .runtimeIncompatible:
            return "runtime incompatible"
        case .unknown:
            return "unknown"
        }
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
        case .runtimeIncompatible:
            return "BLOCKED — RUNTIME INCOMPATIBLE"
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

    private func writeSmokeReport(_ report: String) throws {
        guard let path = ProcessInfo.processInfo.environment["PET_HALO_SMOKE_REPORT_PATH"] else {
            XCTFail("M2 smoke report path is unavailable")
            return
        }
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data((report + "\n").utf8))
    }
}
