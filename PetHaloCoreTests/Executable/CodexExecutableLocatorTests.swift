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
}
