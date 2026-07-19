import Darwin
import Foundation
import XCTest
@testable import PetHaloCore

final class CodexExecutableLocatorTests: XCTestCase {
    func testExplicitExecutableAndPathDiscoveryResolveSymlinks() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("real-codex")
        XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let symlink = directory.appendingPathComponent("codex")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: executable)

        let explicit = CodexExecutableLocator(explicitExecutableURL: symlink)
        let explicitResult = await explicit.locate()
        XCTAssertEqual(explicitResult, .available(executable.resolvingSymlinksInPath()))

        let path = CodexExecutableLocator(
            environment: ["PATH": directory.path],
            commonPrefixes: []
        )
        let pathResult = await path.locate()
        XCTAssertEqual(pathResult, .available(executable.resolvingSymlinksInPath()))
    }

    func testMissingAndNonExecutableCandidatesAreUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let candidate = directory.appendingPathComponent("codex")
        XCTAssertTrue(FileManager.default.createFile(atPath: candidate.path, contents: Data()))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: candidate.path
        )

        let locator = CodexExecutableLocator(
            environment: ["PATH": directory.path],
            commonPrefixes: []
        )
        let result = await locator.locate()
        XCTAssertEqual(result, .unavailable)
    }

    func testRelativePathEntriesAreIgnored() async {
        let locator = CodexExecutableLocator(
            environment: ["PATH": ".:relative/bin"],
            commonPrefixes: []
        )

        let result = await locator.locate()
        XCTAssertEqual(result, .unavailable)
    }

    func testVersionInspectorAcceptsOnlyBoundedSuccessfulCodexOutput() async throws {
        let valid = try makeExecutable(body: "print('codex-cli 0.145.0-alpha.18')")
        defer { try? FileManager.default.removeItem(at: valid.deletingLastPathComponent()) }
        let malformed = try makeExecutable(body: "print('prefix codex-cli 0.145.0')")
        defer { try? FileManager.default.removeItem(at: malformed.deletingLastPathComponent()) }
        let nonzero = try makeExecutable(body: "raise SystemExit(7)")
        defer { try? FileManager.default.removeItem(at: nonzero.deletingLastPathComponent()) }
        let oversized = try makeExecutable(body: "import time\nprint('x' * 8192, flush=True)\ntime.sleep(60)")
        defer { try? FileManager.default.removeItem(at: oversized.deletingLastPathComponent()) }
        let inspector = CodexVersionInspector(
            timeout: .seconds(5),
            maximumOutputBytes: 128,
            shutdownGrace: .milliseconds(50)
        )

        let validResult = await inspector.inspect(executableURL: valid)
        let malformedResult = await inspector.inspect(executableURL: malformed)
        let nonzeroResult = await inspector.inspect(executableURL: nonzero)
        let oversizedResult = await inspector.inspect(executableURL: oversized)
        XCTAssertEqual(validResult, .available("0.145.0-alpha.18"))
        XCTAssertEqual(malformedResult, .unavailable)
        XCTAssertEqual(nonzeroResult, .unavailable)
        XCTAssertEqual(oversizedResult, .unavailable)
    }

    func testVersionInspectorTimeoutTerminatesAndReapsChild() async throws {
        let pidFile = temporaryPIDFile()
        let executable = try makeExecutable(
            body: "import os, signal, time\n"
                + "open(\(pythonLiteral(pidFile.path)), 'w').write(str(os.getpid()))\n"
                + "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                + "time.sleep(60)"
        )
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let inspector = CodexVersionInspector(
            timeout: .seconds(1),
            shutdownGrace: .milliseconds(50)
        )

        let result = await inspector.inspect(executableURL: executable)
        XCTAssertEqual(result, .unavailable)
        let pid = try readPID(pidFile)
        assertProcessDoesNotExist(pid)
    }

    func testVersionInspectorCancellationTerminatesAndReapsChild() async throws {
        let pidFile = temporaryPIDFile()
        let executable = try makeExecutable(
            body: "import os, signal, time\n"
                + "open(\(pythonLiteral(pidFile.path)), 'w').write(str(os.getpid()))\n"
                + "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                + "time.sleep(60)"
        )
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let inspector = CodexVersionInspector(
            timeout: .seconds(10),
            shutdownGrace: .milliseconds(50)
        )
        let inspection = Task {
            await inspector.inspect(executableURL: executable)
        }
        let pid = try await waitForPID(pidFile)

        inspection.cancel()
        let result = await inspection.value
        XCTAssertEqual(result, .unavailable)
        assertProcessDoesNotExist(pid)
    }

    private func makeExecutable(body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("codex")
        let source = "#!/usr/bin/python3\n" + body + "\n"
        try Data(source.utf8).write(to: executable, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return executable
    }

    private func temporaryPIDFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).pid")
    }

    private func pythonLiteral(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "\\'") + "'"
    }

    private func waitForPID(_ url: URL) async throws -> Int32 {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while clock.now < deadline {
            if let pid = try? readPID(url) {
                return pid
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw JSONRPCClientError.requestTimedOut
    }

    private func readPID(_ url: URL) throws -> Int32 {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try XCTUnwrap(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private func assertProcessDoesNotExist(_ pid: Int32) {
        errno = 0
        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }
}
