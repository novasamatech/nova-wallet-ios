import XCTest
@testable import NovaAuth

final class NovaAuthRepeatedDenialTests: LifecycleTestCase {
    func testIssuerRetainsCooldownAndRejectionWhenRepeatedDenialCannotDeleteBearer() throws {
        try assertRepeatedDenialSurvivesDeletionFailure(useReader: false)
    }

    func testReaderRetainsCooldownAndRejectionWhenRepeatedDenialCannotDeleteBearer() throws {
        try assertRepeatedDenialSurvivesDeletionFailure(useReader: true)
    }
}

private extension NovaAuthRepeatedDenialTests {
    func assertRepeatedDenialSurvivesDeletionFailure(
        useReader: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let client: NovaAuthClientProtocol = useReader ? harness.makeReader() : auth
        let authority = try XCTUnwrap(client as? NovaAuthCredentialAuthority)
        let replacement = harness.record(context: context, bearer: "main-app-replacement")
        harness.http.handler = { request, completion in
            completion(Result {
                if harness.http.requests.count == 1, useReader {
                    try harness.tokens.replace(replacement)
                }
                if harness.http.requests.count == 2 { harness.tokens.failRemove = true }
                return try LifecycleHTTP.response(
                    request: request,
                    status: 401,
                    headers: NovaAuthRecoveryTests.denialHeaders,
                    body: NovaAuthRecoveryTests.denialBody
                )
            })
        }
        defer { harness.http.handler = nil }
        let request = try harness.request(context: context)
        assertError(
            .storageUnavailable,
            client.createResponseWrapper(for: request, beforeSend: {}),
            on: harness.callers, file: file, line: line
        )
        let rejected = try XCTUnwrap(harness.tokens.load())
        XCTAssertEqual(
            rejected.accessToken,
            useReader ? replacement.accessToken : harness.bootstrap.tokenResult.accessToken,
            file: file, line: line
        )
        assertError(
            .cooldown(retryAfter: 1.5),
            client.createAdmissionWrapper(in: context, intent: .background),
            on: harness.callers, file: file, line: line
        )
        XCTAssertEqual(harness.http.requests.count, 2, file: file, line: line)
        XCTAssertEqual(harness.bootstrap.tokens.count, useReader ? 0 : 1, file: file, line: line)
        harness.clock.advance(1.5)
        XCTAssertThrowsError(try authority.checkSend(request: request, record: rejected), file: file, line: line) {
            XCTAssertEqual($0 as? NovaAuthError, .credentialUnavailable, file: file, line: line)
        }
        XCTAssertEqual(try harness.tokens.load(), rejected, file: file, line: line)
    }
}
