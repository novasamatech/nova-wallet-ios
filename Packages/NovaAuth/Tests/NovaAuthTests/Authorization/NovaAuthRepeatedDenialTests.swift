import XCTest
@testable import NovaAuth

final class NovaAuthRepeatedDenialTests: LifecycleTestCase {
    func testIssuerRetainsCooldownAndRejectionWhenRepeatedDenialCannotDeleteBearer() throws {
        try assertRepeatedDenialSurvivesDeletionFailure()
    }
}

private extension NovaAuthRepeatedDenialTests {
    func assertRepeatedDenialSurvivesDeletionFailure(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let authority: NovaAuthCredentialAuthority = auth
        harness.http.handler = { request, completion in
            completion(Result {
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
            auth.createResponseWrapper(for: request, beforeSend: {}),
            on: harness.callers, file: file, line: line
        )
        let rejected = try XCTUnwrap(harness.tokens.load())
        XCTAssertEqual(rejected.accessToken, harness.bootstrap.tokenResult.accessToken, file: file, line: line)
        assertError(
            .cooldown(retryAfter: 1.5),
            auth.createAdmissionWrapper(in: context, intent: .background),
            on: harness.callers, file: file, line: line
        )
        XCTAssertEqual(harness.http.requests.count, 2, file: file, line: line)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1, file: file, line: line)
        harness.clock.advance(1.5)
        XCTAssertThrowsError(try authority.checkSend(request: request, record: rejected), file: file, line: line) {
            XCTAssertEqual($0 as? NovaAuthError, .credentialUnavailable, file: file, line: line)
        }
        XCTAssertEqual(try harness.tokens.load(), rejected, file: file, line: line)
    }
}
