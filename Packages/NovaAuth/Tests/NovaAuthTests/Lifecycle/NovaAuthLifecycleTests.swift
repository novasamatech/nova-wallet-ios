import XCTest
@testable import NovaAuth

final class NovaAuthLifecycleTests: XCTestCase {
    func testFirstUserDemandRegistersOnceAndLaterDemandReusesTheBearer() throws {
        let harness = try AuthHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        try execute(auth.createResponseWrapper(for: harness.request(context), beforeSend: {}))
        try execute(auth.createResponseWrapper(for: harness.request(context), beforeSend: {}))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.server.count("/tokens"), 1)
        XCTAssertEqual(
            harness.server.businessRequests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer bearer-1", "Bearer bearer-1"]
        )
    }

    func testRefusedRegistrationMintsNoBackgroundKeyAndOneKeyPerUserAction() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 401, body: FakeAuthServer.error("attestation_failed")))
        let refusal = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "attestation_failed", requestID: nil, retryAfter: nil
        ))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background))
        harness.clock.advance(100_000)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background))
        let relaunched = try harness.relaunch()
        assertError(.userActionRequired, relaunched.createAdmissionWrapper(in: context, intent: .background))
        XCTAssertEqual(harness.apple.keys, 1)
        assertError(refusal, relaunched.createAdmissionWrapper(in: context, intent: .userInitiated))
        XCTAssertEqual(harness.apple.keys, 2)
    }

    func testLostKeyAllowsTwoBackgroundRecreationsThenOnlyUserAction() throws {
        let harness = try AuthHarness()
        let (_, context) = try registered(harness)
        harness.apple.assertionError = NovaAuthAppAttestError.invalidKey
        for _ in 0 ..< 3 {
            harness.clock.advance(100_000)
            assertError(.keyUnavailable, try harness.relaunch().createAdmissionWrapper(in: context, intent: .background))
        }
        harness.clock.advance(100_000)
        let auth = try harness.relaunch()
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background))
        XCTAssertEqual(harness.apple.keys, 3)
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated))
        XCTAssertEqual(harness.apple.keys, 4)
    }

    func testLostRegistrationResponseRecoversThroughTokenChallengeWithoutSecondAttestation() throws {
        let harness = try AuthHarness()
        harness.server.registration = .failure(URLError(.networkConnectionLost))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.transport(.networkConnectionLost), auth.createAdmissionWrapper(in: context, intent: .userInitiated))
        harness.clock.advance(2)
        try execute(harness.relaunch().createAdmissionWrapper(in: context, intent: .userInitiated))
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.server.count("/register"), 1)
    }

    func testExpiredDeferredAttestationIsRetiredWithoutAppleAndNotRecreatedInBackground() throws {
        let harness = try AuthHarness()
        harness.apple.attestationError = NovaAuthAppAttestError.serverUnavailable
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background))
        harness.apple.attestationError = nil
        harness.clock.advance(41)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background))
        harness.clock.advance(100_000)
        assertError(.userActionRequired, try harness.relaunch().createAdmissionWrapper(in: context, intent: .background))
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testResetDiscardsTheLateTokenOfTheOldGeneration() throws {
        let harness = try AuthHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        let sent = expectation(description: "token request sent")
        let release = DispatchSemaphore(value: 0)
        harness.server.beforeToken = {
            sent.fulfill()
            _ = release.wait(timeout: .now() + 5)
        }
        let admission = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        OperationQueue().addOperations(admission.allOperations, waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        try auth.reset()
        let installed = expectation(description: "late bearer installed")
        installed.isInverted = true
        harness.tokens.onReplace = { installed.fulfill() }
        release.signal()
        wait(for: [installed], timeout: 1)
        XCTAssertNil(try harness.tokens.load())
    }

    func testCorruptIdentityRecordIsRepairedOnActivate() throws {
        let harness = try AuthHarness()
        let (_, previous) = try registered(harness)
        harness.settings.set(value: Data("not-json".utf8), for: NovaAuthSettingsIdentityStore.storageKey)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        XCTAssertGreaterThan(context.generation, previous.generation)
        XCTAssertNil(try harness.tokens.load())
        try execute(auth.createAdmissionWrapper(in: context, intent: .background))
        XCTAssertEqual(harness.apple.keys, 2)
    }
}
