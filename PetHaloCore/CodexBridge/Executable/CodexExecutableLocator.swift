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
                .map { URL(fileURLWithPath: String($0), isDirectory: true).appendingPathComponent("codex") }
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
    public init() {}

    public func inspect(executableURL: URL) async -> CodexVersionInspection {
        let process = Process()
        let stdout = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                return .unavailable
            }
            let data = try stdout.fileHandleForReading.read(upToCount: 4_096) ?? Data()
            guard let output = String(data: data, encoding: .utf8) else {
                return .unavailable
            }
            let parts = output.split(whereSeparator: { $0.isWhitespace })
            guard let marker = parts.firstIndex(of: "codex-cli"), parts.indices.contains(marker + 1) else {
                return .unavailable
            }
            let version = String(parts[marker + 1])
            guard !version.isEmpty else {
                return .unavailable
            }
            return .available(version)
        } catch {
            return .unavailable
        }
    }
}
