import Darwin
import Foundation

public enum CodexProcessError: Error, Equatable, Sendable {
    case alreadyStarted
    case launchFailed
    case transportClosed
    case invalidFraming
    case processExited(code: Int32)
}

public actor CodexAppServerProcess: JSONRPCTransport {
    private let executableURL: URL
    private let arguments: [String]
    private let shutdownGraceNanoseconds: UInt64
    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation
    private let stdoutChunkStream: AsyncStream<Data>
    private let stdoutChunkContinuation: AsyncStream<Data>.Continuation

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutReadTask: Task<Void, Never>?
    private var framer: JSONLFramer
    private var stopping = false
    private var finished = false
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        executableURL: URL,
        arguments: [String] = ["app-server", "--stdio"],
        maximumMessageSize: Int = JSONLFramer.defaultMaximumMessageSize,
        shutdownGraceNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.shutdownGraceNanoseconds = shutdownGraceNanoseconds
        framer = JSONLFramer(maximumMessageSize: maximumMessageSize)
        let pair = AsyncThrowingStream.makeStream(
            of: Data.self,
            throwing: Error.self,
            bufferingPolicy: .bufferingOldest(64)
        )
        messageStream = pair.stream
        messageContinuation = pair.continuation
        let stdoutPair = AsyncStream.makeStream(
            of: Data.self,
            bufferingPolicy: .bufferingOldest(16)
        )
        stdoutChunkStream = stdoutPair.stream
        stdoutChunkContinuation = stdoutPair.continuation
    }

    public func inboundMessages() -> AsyncThrowingStream<Data, Error> {
        messageStream
    }

    public func start() async throws {
        guard process == nil else {
            throw CodexProcessError.alreadyStarted
        }
        guard !stopping, !finished else {
            throw CodexProcessError.transportClosed
        }

        let child = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        child.executableURL = executableURL
        child.arguments = arguments
        child.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        child.standardInput = input
        child.standardOutput = output
        child.standardError = errors

        let chunkContinuation = stdoutChunkContinuation
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            switch chunkContinuation.yield(data) {
            case .enqueued:
                break
            case .dropped, .terminated:
                Task { [weak self] in
                    await self?.stdoutDeliveryFailed()
                }
            @unknown default:
                Task { [weak self] in
                    await self?.stdoutDeliveryFailed()
                }
            }
        }
        errors.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        child.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { [weak self] in
                await self?.processDidExit(status: status)
            }
        }

        do {
            try child.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            errors.fileHandleForReading.readabilityHandler = nil
            closeHandles(input: input, output: output, errors: errors)
            throw CodexProcessError.launchFailed
        }

        process = child
        stdinPipe = input
        stdoutPipe = output
        stderrPipe = errors
        let chunks = stdoutChunkStream
        stdoutReadTask = Task { [weak self, chunks] in
            for await data in chunks {
                guard let self else { return }
                await self.consumeStdout(data)
            }
        }
    }

    public func send(_ data: Data) async throws {
        guard !stopping,
              !finished,
              let process,
              process.isRunning,
              let handle = stdinPipe?.fileHandleForWriting
        else {
            throw CodexProcessError.transportClosed
        }
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw CodexProcessError.transportClosed
        }
    }

    public func stop() async {
        if stopping {
            await withCheckedContinuation { continuation in
                stopWaiters.append(continuation)
            }
            return
        }
        stopping = true
        defer {
            stopping = false
            let waiters = stopWaiters
            stopWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        finishStdoutReader()
        try? stdinPipe?.fileHandleForWriting.close()

        if process?.isRunning == true {
            process?.terminate()
            await waitForExit(nanoseconds: shutdownGraceNanoseconds)
        }
        if process?.isRunning == true, let pid = process?.processIdentifier {
            Darwin.kill(pid, SIGKILL)
            await waitForExit(nanoseconds: shutdownGraceNanoseconds)
        }

        finishStream()
        closeOwnedHandles()
        process = nil
    }

    func processIdentifierForTesting() -> Int32? {
        process?.processIdentifier
    }

    private func consumeStdout(_ data: Data) async {
        guard !finished, !stopping else { return }
        if data.isEmpty {
            finishUnexpectedly(.transportClosed)
            return
        }
        do {
            let messages = try framer.append(data)
            for message in messages {
                switch messageContinuation.yield(message) {
                case .enqueued:
                    break
                case .dropped, .terminated:
                    finishUnexpectedly(.invalidFraming)
                    if process?.isRunning == true {
                        process?.terminate()
                    }
                    return
                @unknown default:
                    finishUnexpectedly(.invalidFraming)
                    return
                }
            }
        } catch {
            finishUnexpectedly(.invalidFraming)
            if process?.isRunning == true {
                process?.terminate()
            }
        }
    }

    private func stdoutDeliveryFailed() {
        guard !finished, !stopping else { return }
        finishUnexpectedly(.invalidFraming)
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func processDidExit(status: Int32) {
        if !finished {
            if stopping {
                finishStream()
            } else {
                finishUnexpectedly(.processExited(code: status))
            }
        }
        closeOwnedHandles()
    }

    private func waitForExit(nanoseconds: UInt64) async {
        let deadline = DispatchTime.now().uptimeNanoseconds &+ nanoseconds
        while process?.isRunning == true, DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func finishUnexpectedly(_ error: CodexProcessError) {
        guard !finished else { return }
        finished = true
        finishStdoutReader()
        messageContinuation.finish(throwing: error)
    }

    private func finishStream() {
        guard !finished else { return }
        finished = true
        finishStdoutReader()
        messageContinuation.finish()
    }

    private func finishStdoutReader() {
        stdoutChunkContinuation.finish()
        stdoutReadTask?.cancel()
        stdoutReadTask = nil
    }

    private func closeOwnedHandles() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if let stdinPipe, let stdoutPipe, let stderrPipe {
            closeHandles(input: stdinPipe, output: stdoutPipe, errors: stderrPipe)
        }
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    private nonisolated func closeHandles(input: Pipe, output: Pipe, errors: Pipe) {
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        try? errors.fileHandleForReading.close()
    }
}
