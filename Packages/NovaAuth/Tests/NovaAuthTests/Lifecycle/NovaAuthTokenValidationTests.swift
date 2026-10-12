import XCTest
@testable import NovaAuth

final class NovaAuthTokenValidationTests: LifecycleTestCase {
    func testSameBootRestartReusesPersistedTokenWithoutBootstrapOrRandomDraw() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        let draws = harness.random.draws
        let restarted = harness.makeAuth()
        XCTAssertEqual(try restarted.activate(origin: harness.origin), context)
        harness.clock.advance(100)
        try execute(restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertEqual(harness.random.draws, draws)
    }

    func testTokenMustBePersistedBeforeAnyBusinessSend() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.http.handler = { request, completion in
            do {
                let stored = try XCTUnwrap(harness.tokens.load())
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + stored.accessToken)
                completion(.success(try LifecycleHTTP.response(request: request)))
            } catch { completion(.failure(error)) }
        }
        try execute(auth.createResponseWrapper(for: harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.tokens.replacements, 1)
    }

    func testExpiredOnArrivalFailsOnceWithoutInstallingOrReissuing() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.bootstrap.onToken = { completion in
            harness.clock.advance(595)
            completion(.success(harness.bootstrap.tokenResult))
        }
        assertError(.credentialUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertNil(try harness.tokens.load())
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testSecureSaveFailureNeverExposesTokenOrSendsBusinessRequest() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.tokens.failSave = true
        assertError(.storageUnavailable, auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 0)
        XCTAssertNil(try harness.tokens.load())
    }

    func testStorageAndClockReadFailuresDoNotBootstrap() throws {
        for storageFailure in [true, false] {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            if storageFailure { harness.tokens.failLoad = true }
            else { harness.clock.failure = NovaAuthError.clockUnavailable }
            assertError(
                storageFailure ? .storageUnavailable : .clockUnavailable,
                auth.createAdmissionWrapper(in: context, intent: .userInitiated),
                on: harness.callers
            )
            XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        }
    }

    func testRebootExpiryAndFutureMonotonicRecordAreReplaced() throws {
        for mode in 0 ..< 3 {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered(withToken: true)
            if mode == 0 { harness.clock.reboot() }
            if mode == 1 { harness.clock.advance(595) }
            if mode == 2 { try harness.tokens.replace(harness.record(context: context, start: 1000)) }
            try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
            XCTAssertEqual(harness.bootstrap.tokens.count, 1)
            XCTAssertEqual(try harness.tokens.load()?.issuanceStart.bootID, try harness.clock.now().bootID)
        }
    }

    func testStoredThresholdIsCheckedAndDeadlineIsCalendarIndependent() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let record = harness.record(context: context)
        XCTAssertEqual(try NovaAuthTokenValidation.remaining(
            record,
            context: context,
            clientID: record.clientID,
            now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 200)
        ), 495)
        let invalid = harness.record(context: context, threshold: 999)
        XCTAssertThrowsError(try NovaAuthTokenValidation.remaining(invalid, context: context, clientID: nil, now: harness.clock.now()))
        XCTAssertThrowsError(try NovaAuthTokenValidation.remaining(record, context: context, clientID: "wrong", now: harness.clock.now()))
    }
}
