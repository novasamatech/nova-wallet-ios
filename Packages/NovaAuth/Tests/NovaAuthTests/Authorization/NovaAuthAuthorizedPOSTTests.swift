import XCTest
@testable import NovaAuth

final class NovaAuthAuthorizedPOSTTests: LifecycleTestCase {
    func testUnknownTransportOutcomeAndServerErrorNeverReplayPost() throws {
        for transport in [true, false] {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            harness.http.handler = { request, completion in
                if transport { completion(.failure(NovaAuthError.transport(.networkConnectionLost))) }
                else { completion(Result { try LifecycleHTTP.response(request: request, status: 500) }) }
            }
            let request = try harness.request(context: context, method: .post, body: Data("{\"events\":[]}".utf8))
            let wrapper = auth.createResponseWrapper(for: request, beforeSend: {})
            if transport { assertError(.transport(.networkConnectionLost), wrapper, on: harness.callers) }
            else { try execute(wrapper, on: harness.callers) }
            XCTAssertEqual(harness.http.requests.count, 1)
            XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        }
    }

    func testConsentRevokedDuringInitialIssuancePreventsFirstTaskResume() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        var allowed = true
        harness.bootstrap.onToken = { completion in
            allowed = false
            completion(.success(harness.bootstrap.tokenResult))
        }
        let request = try harness.request(context: context, method: .post, body: Data("{}".utf8))
        assertError(.cancelled, auth.createResponseWrapper(for: request, beforeSend: {
            if !allowed { throw NovaAuthError.cancelled }
        }), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 0)
        XCTAssertNotNil(try harness.tokens.load())
    }

    func testConsentRevokedDuringRecoveryPreventsRepeatTaskResume() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        var allowed = true
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(
                request: request,
                status: 401,
                headers: NovaAuthRecoveryTests.denialHeaders,
                body: NovaAuthRecoveryTests.denialBody
            ) })
        }
        harness.bootstrap.onToken = { completion in
            allowed = false
            completion(.success(harness.bootstrap.tokenResult))
        }
        let request = try harness.request(context: context, method: .post, body: Data("{}".utf8))
        assertError(.cancelled, auth.createResponseWrapper(for: request, beforeSend: {
            if !allowed { throw NovaAuthError.cancelled }
        }), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testCancellationAfterPostSendDoesNotReplayEvenOnLateConclusiveDenial() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let sent = expectation(description: "POST sent")
        var pending: ((Result<NovaAuthResponse, Error>) -> Void)?
        var sentRequest: URLRequest?
        harness.http.handler = { request, completion in
            pending = completion
            sentRequest = request
            sent.fulfill()
        }
        let wrapper = auth.createResponseWrapper(for: try harness.request(context: context, method: .post, body: Data("{}".utf8)), beforeSend: {})
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        wrapper.cancel()
        pending?(.success(try LifecycleHTTP.response(
            request: XCTUnwrap(sentRequest),
            status: 401,
            headers: NovaAuthRecoveryTests.denialHeaders,
            body: NovaAuthRecoveryTests.denialBody
        )))
        drain(harness.ownerQueue)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        XCTAssertNotNil(try harness.tokens.load())
    }
}
