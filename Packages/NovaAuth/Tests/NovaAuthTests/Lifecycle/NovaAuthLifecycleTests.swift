@testable import NovaAuth
import XCTest

final class NovaAuthLifecycleTests: XCTestCase {
    func testFirstDemandRegistersOnceAndLaterDemandReusesTheBearer() throws {
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

    func testRefusedRegistrationFailsThenLaterIndependentDemandCreatesOneKey() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 401, body: FakeAuthServer.error("attestation_failed")))
        let refusal = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "attestation_failed", requestID: nil, retryAfter: nil
        ))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        harness.clock.advance(2)
        try assertError(refusal, harness.relaunch().createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 2)
    }

    func testLostKeyFailsWithoutReplacingUntilLaterIndependentDemand() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        harness.apple.assertionError = NovaAuthAppAttestError.invalidKey
        harness.clock.advance(1000)
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        harness.apple.assertionError = nil
        harness.clock.advance(2)
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 2)
    }

    func testTokenRefusalPreservesRegisteredBindingForLaterDemand() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        let identity = auth.state?.identity
        harness.clock.advance(1000)
        harness.server.token = .init(status: 401, body: FakeAuthServer.error("invalid_proof"))
        assertError(.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "invalid_proof", requestID: nil, retryAfter: nil
        )), auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(auth.state?.identity, identity)
        harness.server.token = nil
        harness.clock.advance(2)
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.server.count("/token-challenges"), 3)
    }

    func testLostRegistrationResponseRecoversThroughTokenChallengeWithoutSecondAttestation() throws {
        let harness = try AuthHarness()
        harness.server.registration = .failure(URLError(.networkConnectionLost))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.transport(.networkConnectionLost), auth.createAdmissionWrapper(in: context))
        let pendingIdentity = auth.state?.identity
        harness.server.token = .init(status: 401, body: FakeAuthServer.error("unknown_client"))
        harness.clock.advance(2)
        let relaunched = try harness.relaunch()
        assertError(.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "unknown_client", requestID: nil, retryAfter: nil
        )), relaunched.createAdmissionWrapper(in: context))
        XCTAssertEqual(relaunched.state?.identity?.clientID, pendingIdentity?.clientID)
        XCTAssertEqual(relaunched.state?.identity?.keyID, pendingIdentity?.keyID)
        harness.server.token = nil
        harness.clock.advance(2)
        try execute(relaunched.createAdmissionWrapper(in: context))
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.server.count("/register"), 1)
    }

    func testExpiredDeferredAttestationTakesAFreshChallengeWithTheSameKey() throws {
        let harness = try AuthHarness()
        harness.apple.attestationError = NovaAuthAppAttestError.serverUnavailable
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context))
        harness.apple.attestationError = nil
        harness.clock.advance(41)
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations, 2)
        XCTAssertEqual(harness.server.count("/challenges"), 2)
    }

    func testDeferredAttestationInsideTheWindowRetriesTheSavedKeyAndAttempt() throws {
        let harness = try AuthHarness()
        harness.apple.attestationError = NovaAuthAppAttestError.serverUnavailable
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context))
        harness.apple.attestationError = nil
        harness.clock.advance(39)
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations, 2)
        XCTAssertEqual(harness.server.count("/challenges"), 1)
    }

    func testOriginChangeDiscardsTheLateTokenOfTheOldGeneration() throws {
        let harness = try AuthHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        let sent = expectation(description: "token request sent")
        let release = DispatchSemaphore(value: 0)
        harness.server.beforeToken = {
            sent.fulfill()
            _ = release.wait(timeout: .now() + 5)
        }
        let admission = auth.createAdmissionWrapper(in: context)
        OperationQueue().addOperations(admission.allOperations, waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        _ = try auth.activate(origin: NovaAuthOrigin("https://other.example.com"))
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
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 2)
    }
}
