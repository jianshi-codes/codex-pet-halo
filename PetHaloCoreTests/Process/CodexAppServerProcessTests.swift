import Darwin
import Foundation
import XCTest
@testable import PetHaloCore

final class CodexAppServerProcessTests: XCTestCase {
    func testRealChildProcessHandshakePartialOutputStderrAndCleanShutdown() async throws {
        for scenario in ["valid", "partial", "stderr"] {
            let transport = try makeTransport(scenario: scenario)
            let client = JSONRPCClient(transport: transport)
            try await client.start()
            _ = try await client.request(.initialize, params: initializeParams)
            try await client.notify(.initialized)
            let response = try await client.request(
                .accountRead,
                params: .object(["refreshToken": .bool(false)])
            )
            let account = try CodexDTOCodec.decode(AccountAvailabilityDTO.self, from: response)
            XCTAssertTrue(account.accountAvailable)
            let processIdentifier = await transport.processIdentifierForTesting()
            let pid = try XCTUnwrap(processIdentifier)

            await client.close()
            XCTAssertEqual(Darwin.kill(pid, 0), -1)
            XCTAssertEqual(errno, ESRCH)
        }
    }

    func testRequestBeforeInitializationIsRejected() async throws {
        let transport = try makeTransport(scenario: "valid")
        let client = JSONRPCClient(transport: transport)
        try await client.start()

        do {
            _ = try await client.request(.rateLimitsRead)
            XCTFail("Expected initialization rejection")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .remoteError(code: -32_002))
        }
        await client.close()
    }

    func testMalformedOutputAndAbruptExitDisconnectClient() async throws {
        let malformedTransport = try makeTransport(scenario: "malformed")
        let malformedClient = JSONRPCClient(transport: malformedTransport)
        try await malformedClient.start()
        do {
            _ = try await malformedClient.request(.initialize, params: initializeParams)
            XCTFail("Expected malformed message failure")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .invalidMessage)
        }

        let abruptTransport = try makeTransport(scenario: "abrupt")
        let abruptClient = JSONRPCClient(transport: abruptTransport)
        try await abruptClient.start()
        _ = try await abruptClient.request(.initialize, params: initializeParams)
        try await abruptClient.notify(.initialized)
        do {
            _ = try await abruptClient.request(.rateLimitsRead)
            XCTFail("Expected abrupt disconnect")
        } catch {
            XCTAssertEqual(error as? JSONRPCClientError, .transportClosed)
        }
    }

    func testConcurrentStopWaitersReturnAfterChildExit() async throws {
        let transport = try makeTransport(scenario: "valid")
        let client = JSONRPCClient(transport: transport)
        try await client.start()
        let processIdentifier = await transport.processIdentifierForTesting()
        let pid = try XCTUnwrap(processIdentifier)

        async let first: Void = transport.stop()
        async let second: Void = transport.stop()
        _ = await (first, second)

        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    private var initializeParams: JSONValue {
        .object([
            "clientInfo": .object([
                "name": .string("pet_halo"),
                "title": .string("Pet Halo"),
                "version": .string("test"),
            ]),
            "capabilities": .object([
                "experimentalApi": .bool(true),
                "requestAttestation": .bool(false),
            ]),
        ])
    }

    private func makeTransport(scenario: String) throws -> CodexAppServerProcess {
        let script = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "fake_app_server", withExtension: "py")
        )
        return CodexAppServerProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [script.path, scenario],
            shutdownGraceNanoseconds: 500_000_000
        )
    }
}
