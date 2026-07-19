import Darwin
import Foundation

public enum CodexExecutableLocation: Equatable, Sendable {
    case available(URL)
    case unavailable
}

public protocol CodexExecutableLocating: Sendable {
    func locate() async -> CodexExecutableLocation
}

public struct CodexExecutableLocator: CodexExecutableLocating, Sendable {
    private let explicitExecutableURL: URL?
    private let environmentPath: String?
    private let commonPrefixes: [URL]

    public init(
        explicitExecutableURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        commonPrefixes: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources", isDirectory: true),
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources", isDirectory: true),
        ]
    ) {
        self.explicitExecutableURL = explicitExecutableURL
        environmentPath = environment["PATH"]
        self.commonPrefixes = commonPrefixes
    }

    public func locate() async -> CodexExecutableLocation {
        let candidates: [URL]
        if let explicitExecutableURL {
            candidates = [explicitExecutableURL]
        } else {
            let pathCandidates = (environmentPath ?? "")
                .split(separator: ":", omittingEmptySubsequences: true)
                .map(String.init)
                .filter { $0.hasPrefix("/") }
                .map { URL(fileURLWithPath: $0, isDirectory: true).appendingPathComponent("codex") }
            candidates = pathCandidates + commonPrefixes.map { $0.appendingPathComponent("codex") }
        }

        for candidate in candidates {
            if let validated = validate(candidate) {
                return .available(validated)
            }
        }
        return .unavailable
    }

    private func validate(_ candidate: URL) -> URL? {
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isExecutableFile(atPath: resolved.path)
        else {
            return nil
        }
        return resolved
    }
}

public enum CodexVersionInspection: Equatable, Sendable {
    case available(String)
    case unavailable
}

public protocol CodexVersionInspecting: Sendable {
    func inspect(executableURL: URL) async -> CodexVersionInspection
}

public struct CodexVersionInspector: CodexVersionInspecting, Sendable {
    public static let defaultTimeout: Duration = .seconds(5)
    public static let defaultMaximumOutputBytes = 4_096

    private let timeout: Duration
    private let maximumOutputBytes: Int
    private let shutdownGrace: Duration

    public init(
        timeout: Duration = CodexVersionInspector.defaultTimeout,
        maximumOutputBytes: Int = CodexVersionInspector.defaultMaximumOutputBytes,
        shutdownGrace: Duration = .seconds(1)
    ) {
        precondition(maximumOutputBytes > 0)
        self.timeout = timeout
        self.maximumOutputBytes = maximumOutputBytes
        self.shutdownGrace = shutdownGrace
    }

    public func inspect(executableURL: URL) async -> CodexVersionInspection {
        let probe = CodexVersionProbe(
            executableURL: executableURL,
            timeout: timeout,
            maximumOutputBytes: maximumOutputBytes,
            shutdownGrace: shutdownGrace
        )
        return await withTaskCancellationHandler {
            await probe.run()
        } onCancel: {
            Task {
                await probe.cancel()
            }
        }
    }
}

private final class BoundedOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var data = Data()
    private var exceeded = false

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    func consume(_ chunk: Data) -> Bool {
        guard !chunk.isEmpty else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard !exceeded else { return false }
        if chunk.count > maximumBytes - data.count {
            exceeded = true
            data.removeAll(keepingCapacity: false)
            return true
        }
        data.append(chunk)
        return false
    }

    func snapshot() -> (data: Data, exceeded: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (data, exceeded)
    }
}

private actor CodexVersionProbe {
    private let executableURL: URL
    private let timeout: Duration
    private let shutdownGrace: Duration
    private let output: BoundedOutputCollector

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<CodexVersionInspection, Never>?
    private var completedResult: CodexVersionInspection?
    private var forcedUnavailable = false

    init(
        executableURL: URL,
        timeout: Duration,
        maximumOutputBytes: Int,
        shutdownGrace: Duration
    ) {
        self.executableURL = executableURL
        self.timeout = timeout
        self.shutdownGrace = shutdownGrace
        output = BoundedOutputCollector(maximumBytes: maximumOutputBytes)
    }

    func run() async -> CodexVersionInspection {
        guard !Task.isCancelled else { return .unavailable }
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        process.standardOutput = stdout
        process.standardError = stderr

        let output = self.output
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let exceeded = output.consume(handle.availableData)
            if exceeded {
                Task {
                    await self?.forceUnavailableAndStop()
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] _ in
            Task {
                await self?.processDidExit()
            }
        }

        do {
            try process.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            closeHandles(stdout: stdout, stderr: stderr)
            return .unavailable
        }
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()

        self.process = process
        stdoutPipe = stdout
        stderrPipe = stderr
        timeoutTask = Task { [weak self, timeout] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            await self?.forceUnavailableAndStop()
        }

        return await withCheckedContinuation { continuation in
            if let completedResult {
                continuation.resume(returning: completedResult)
            } else {
                self.continuation = continuation
            }
        }
    }

    func cancel() async {
        await forceUnavailableAndStop()
    }

    private func forceUnavailableAndStop() async {
        guard completedResult == nil else { return }
        forcedUnavailable = true
        await terminateAndWait()
        completeAfterExit()
    }

    private func terminateAndWait() async {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: shutdownGrace)
            while process.isRunning, clock.now < deadline {
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        if process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
            while process.isRunning {
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    private func processDidExit() {
        completeAfterExit()
    }

    private func completeAfterExit() {
        guard completedResult == nil else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if let handle = stdoutPipe?.fileHandleForReading {
            while true {
                let chunk = handle.availableData
                guard !chunk.isEmpty else { break }
                _ = output.consume(chunk)
            }
        }

        let result: CodexVersionInspection
        if forcedUnavailable || process?.terminationReason != .exit || process?.terminationStatus != 0 {
            result = .unavailable
        } else {
            result = parse(output.snapshot())
        }
        if let stdoutPipe, let stderrPipe {
            closeHandles(stdout: stdoutPipe, stderr: stderrPipe)
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        completedResult = result
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: result)
    }

    private func parse(_ snapshot: (data: Data, exceeded: Bool)) -> CodexVersionInspection {
        guard !snapshot.exceeded,
              let text = String(data: snapshot.data, encoding: .utf8)
        else {
            return .unavailable
        }
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2,
              parts[0] == "codex-cli"
        else {
            return .unavailable
        }
        let version = String(parts[1])
        return version.isEmpty ? .unavailable : .available(version)
    }

    nonisolated private func closeHandles(stdout: Pipe, stderr: Pipe) {
        try? stdout.fileHandleForReading.close()
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForReading.close()
        try? stderr.fileHandleForWriting.close()
    }
}
