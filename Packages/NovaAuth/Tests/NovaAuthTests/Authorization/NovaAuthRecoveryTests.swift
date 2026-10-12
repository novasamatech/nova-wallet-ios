import XCTest
@testable import NovaAuth

final class NovaAuthRecoveryTests: LifecycleTestCase {
    static let denialBody = Data("{\"error\":{\"code\":\"invalid_token\",\"message\":\"denied\"}}".utf8)
    static let denialHeaders = ["WWW-Authenticate": "Bearer error=\"invalid_token\"", "X-Request-Id": "req-one"]

    func testExactGetHeadAndApprovedPostsRenewAndReplayOnceWithIdenticalBodies() throws {
        let cases: [(NovaAuthMethod, String, Data?)] = [
            (.get, "/v1/bittensor/profile-3/subnets", nil),
            (.head, "/v1/bittensor/profile-3/subnets", nil),
            (.post, "/v1/analytics/events", Data("{\"events\":[{\"value\":1}]}".utf8)),
            (.post, "/v1/bittensor/operations/search", Data("{\"account\":\"alice\",\"page\":0}".utf8))
        ]
        for (method, path, body) in cases {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            harness.http.handler = { request, completion in
                completion(Result {
                    if harness.http.requests.count == 1 {
                        return try LifecycleHTTP.response(
                            request: request,
                            status: 401,
                            headers: Self.denialHeaders,
                            body: method == .head ? Data() : Self.denialBody
                        )
                    }
                    return try LifecycleHTTP.response(request: request)
                })
            }
            let request = try harness.request(context: context, method: method, body: body, path: path)
            let response = try execute(auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
            XCTAssertEqual(response.response.statusCode, 200)
            XCTAssertEqual(harness.http.requests.count, 2)
            XCTAssertEqual(harness.http.requests[0].httpBody, harness.http.requests[1].httpBody)
            XCTAssertEqual(harness.http.requests[0].url, harness.http.requests[1].url)
            XCTAssertEqual(harness.http.requests[0].httpMethod, harness.http.requests[1].httpMethod)
            XCTAssertEqual(harness.bootstrap.tokens.count, 1)
            XCTAssertEqual(harness.apple.keys, 0)
        }
    }

    func testSecondConclusiveDenialFailsAndRemovesOnlyCurrentRetryToken() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(
                request: request,
                status: 401,
                headers: Self.denialHeaders,
                body: Self.denialBody
            ) })
        }
        assertError(
            .authorizationDenied(requestID: "req-one"),
            auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {}),
            on: harness.callers
        )
        XCTAssertEqual(harness.http.requests.count, 2)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertNil(try harness.tokens.load())
        assertError(.cooldown(retryAfter: 1.5), auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
    }

    func testFailedRenewalNeverResendsRejectedBearer() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(
                request: request,
                status: 401,
                headers: Self.denialHeaders,
                body: Self.denialBody
            ) })
        }
        harness.bootstrap.tokenChallengeResult = .failure(NovaAuthError.transport(.notConnectedToInternet))
        assertError(
            .transport(.notConnectedToInternet),
            auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {}),
            on: harness.callers
        )
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertNil(try harness.tokens.load())
    }

    func testLateDenialOfOldBearerPreservesAndUsesNewerCurrentBearer() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let newer = harness.record(context: context, bearer: "replacement-installed-elsewhere")
        harness.http.handler = { request, completion in
            completion(Result {
                if harness.http.requests.count == 1 {
                    try harness.tokens.replace(newer)
                    return try LifecycleHTTP.response(request: request, status: 401, headers: Self.denialHeaders, body: Self.denialBody)
                }
                return try LifecycleHTTP.response(request: request)
            })
        }
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(try harness.tokens.load(), newer)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        XCTAssertEqual(harness.http.requests.count, 2)
        XCTAssertEqual(harness.http.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer " + newer.accessToken)
    }

    func testMissingWrongOrAmbiguousDenialSignalsNeverRenew() throws {
        let variants: [(Int, [String: String], Data)] = [
            (401, [:], Self.denialBody),
            (401, ["WWW-Authenticate": "Basic realm=\"api\""], Self.denialBody),
            (401, ["WWW-Authenticate": "Bearer error=\"invalid_token\", Bearer error=\"invalid_token\""], Self.denialBody),
            (401, ["WWW-Authenticate": "Bearer error=\"insufficient_scope\""], Self.denialBody),
            (401, Self.denialHeaders, Data()),
            (401, Self.denialHeaders, Data("{\"error\":{\"code\":\"unknown\"}}".utf8)),
            (401, Self.denialHeaders, Data("{\"error\":{\"code\":\"invalid_token\",\"code\":\"invalid_token\"}}".utf8)),
            (400, Self.denialHeaders, Self.denialBody), (403, Self.denialHeaders, Self.denialBody),
            (429, Self.denialHeaders, Self.denialBody), (503, Self.denialHeaders, Self.denialBody)
        ]
        for (status, headers, body) in variants {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            harness.http.handler = { request, completion in
                completion(Result { try LifecycleHTTP.response(request: request, status: status, headers: headers, body: body) })
            }
            let response = try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
            XCTAssertEqual(response.response.statusCode, status)
            XCTAssertEqual(harness.http.requests.count, 1)
            XCTAssertEqual(harness.bootstrap.tokens.count, 0)
            XCTAssertNotNil(try harness.tokens.load())
        }
    }

    func testForeignOriginAndHeadBodyCannotConcludeInvalidToken() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let request = try harness.request(context: context)
        let foreignURL = try XCTUnwrap(URL(string: "https://foreign.example.com/v1/bittensor/profile-3/subnets"))
        let foreign = try XCTUnwrap(HTTPURLResponse(
            url: foreignURL,
            statusCode: 401,
            httpVersion: nil,
            headerFields: Self.denialHeaders
        ))
        XCTAssertFalse(NovaAuthBearerDenial.isInvalidToken(NovaAuthResponse(response: foreign, body: Self.denialBody), request: request))
        let head = try harness.request(context: context, method: .head)
        let response = try LifecycleHTTP.response(
            request: URLRequest(url: head.makeURL()),
            status: 401,
            headers: Self.denialHeaders,
            body: Self.denialBody
        )
        XCTAssertFalse(NovaAuthBearerDenial.isInvalidToken(response, request: head))
    }
}
