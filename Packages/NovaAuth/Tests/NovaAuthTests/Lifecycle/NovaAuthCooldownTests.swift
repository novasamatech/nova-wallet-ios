import XCTest
@testable import NovaAuth

final class NovaAuthCooldownTests: LifecycleTestCase {
    func testEarlyRefreshHasSponsorAndUsesCurrentBearerImmediately() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(460)
        let began = expectation(description: "early renewal started")
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onToken = pending.start
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        wait(for: [began], timeout: 5)
        XCTAssertEqual(harness.http.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer original-current-bearer")
        XCTAssertNotNil(auth.gate.novaAuthLocked { auth.flight })
        let installed = expectation(description: "sponsored replacement installed")
        harness.tokens.onReplace = { installed.fulfill() }
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [installed], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testEarly429KeepsUsableBearerButExpiredBearerCannotBypassIssuanceCooldown() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(460)
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let began = expectation(description: "early token attempt")
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onToken = pending.start
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        wait(for: [began], timeout: 5)
        let finished = observeFlight(auth)
        pending.resolve(.failure(NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 429,
            code: "rate_limited",
            requestID: nil,
            retryAfter: 300
        ))))
        wait(for: [finished], timeout: 5)
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        harness.clock.advance(140)
        assertError(.cooldown(retryAfter: 160), auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testCooldownSequenceBoundsJitterAndRebootWithoutTimers() throws {
        var cooldown = NovaAuthCooldown()
        var seconds = 0.0
        for expected in [2.0, 3, 5, 9, 17, 31, 31] {
            let now = NovaAuthTime(bootID: "a", continuousSeconds: seconds)
            cooldown.fail(now: now, random: 1)
            XCTAssertThrowsError(try cooldown.check(now: now)) { XCTAssertEqual($0 as? NovaAuthError, .cooldown(retryAfter: expected)) }
            seconds += expected
            XCTAssertNoThrow(try cooldown.check(now: NovaAuthTime(bootID: "a", continuousSeconds: seconds)))
        }
        cooldown.fail(now: NovaAuthTime(bootID: "a", continuousSeconds: seconds), random: 0, retryAfter: 10000)
        XCTAssertThrowsError(try cooldown.check(now: NovaAuthTime(bootID: "a", continuousSeconds: seconds))) {
            XCTAssertEqual($0 as? NovaAuthError, .cooldown(retryAfter: 905))
        }
        XCTAssertNoThrow(try cooldown.check(now: NovaAuthTime(bootID: "b", continuousSeconds: 0)))
    }

    func testProtected429BlocksBusinessSendEvenWithUsableCachedCredential() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(request: request, status: 429, headers: ["Retry-After": "20"]) })
        }
        let request = try harness.request(context: context)
        let response = try execute(auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(response.response.statusCode, 429)
        assertError(.cooldown(retryAfter: 20), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testBusiness503BackoffPreservesAdmissionAndBlocksAnotherPhysicalSend() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(request: request, status: 503) })
        }
        let request = try harness.request(context: context)
        try execute(auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        assertError(.cooldown(retryAfter: 1.5), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testBusinessTransportBackoffPreservesAdmissionAndBlocksAnotherPhysicalSend() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { _, completion in
            completion(.failure(NovaAuthError.transport(.timedOut)))
        }
        let request = try harness.request(context: context)
        assertError(.transport(.timedOut), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        assertError(.cooldown(retryAfter: 1.5), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testServiceFailuresHoldOffOnlyTheirOwnFamilyForIssuerAndReader() throws {
        for useReader in [false, true] {
            for analyticsFails in [false, true] {
                for transport in [false, true] {
                    let harness = try LifecycleHarness()
                    let (auth, context) = try harness.registered(withToken: true)
                    let client: NovaAuthClientProtocol = useReader ? harness.makeReader() : auth
                    let analytics = try harness.request(context: context, method: .post, body: Data("{}".utf8))
                    let bittensor = try harness.request(context: context)
                    let failing = analyticsFails ? analytics : bittensor
                    let healthy = analyticsFails ? bittensor : analytics
                    harness.http.handler = { request, completion in
                        if request.url?.path != failing.path {
                            completion(Result { try LifecycleHTTP.response(request: request) })
                        } else if transport {
                            completion(.failure(NovaAuthError.transport(.timedOut)))
                        } else {
                            let code = analyticsFails ? "queue_over_capacity" : "dataset_unavailable"
                            let body = Data("{\"error\":{\"code\":\"\(code)\",\"message\":\"retry\"}}".utf8)
                            completion(Result { try LifecycleHTTP.response(request: request, status: 503, body: body) })
                        }
                    }
                    if transport {
                        assertError(.transport(.timedOut), client.createResponseWrapper(for: failing, beforeSend: {}), on: harness.callers)
                    } else { try execute(client.createResponseWrapper(for: failing, beforeSend: {}), on: harness.callers) }
                    try execute(client.createResponseWrapper(for: healthy, beforeSend: {}), on: harness.callers)
                    assertError(.cooldown(retryAfter: 1.5), client.createResponseWrapper(for: failing, beforeSend: {}), on: harness.callers)
                    XCTAssertEqual(harness.http.requests.count, 2)
                    XCTAssertEqual(Set(harness.http.requests.compactMap { $0.value(forHTTPHeaderField: "Authorization") }).count, 1)
                    XCTAssertTrue(harness.bootstrap.tokens.isEmpty)
                }
            }
        }
    }

    func testExplicitAuthServiceFailureStillBlocksBothFamilies() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.http.handler = { request, completion in
            completion(Result { try LifecycleHTTP.response(
                request: request, status: 503, headers: ["Retry-After": "905"],
                body: Data(#"{"error":{"code":"attestation_unavailable","message":"retry"}}"#.utf8)
            ) })
        }
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        let analytics = try harness.request(context: context, method: .post, body: Data("{}".utf8))
        assertError(.cooldown(retryAfter: 905), auth.createResponseWrapper(for: analytics, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 1)
    }
}
