import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthRecoveryPolicyTests: LifecycleTestCase {
    func testLostKeyRecoversOnBackgroundDemandAfterPersistedDelay() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let original = try XCTUnwrap(harness.identity.state?.identity)
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        harness.clock.advance(59)
        assertError(.cooldown(retryAfter: 1), restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
        harness.clock.advance(1)
        harness.apple.assert = nil
        try execute(restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertNotEqual(harness.identity.state?.identity?.clientID, original.clientID)
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations.count, 1)
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertNil(harness.identity.state?.recovery)
    }

    func testFailedReplacementCannotCreateMoreKeysBeforeDelayAcrossRestart() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(60)
        harness.apple.attest = { .createWithError(NovaAuthAppAttestError.failure) }
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        harness.clock.advance(599)
        assertError(.cooldown(retryAfter: 1), restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testRestoredBindingPolicyReusesIdentityAfterPersistedRefusalDelay() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let refusal = policyError("binding_not_allowed")
        harness.bootstrap.tokenChallengeResult = .failure(refusal)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        harness.clock.advance(59)
        assertError(.cooldown(retryAfter: 1), restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(1)
        harness.bootstrap.tokenChallengeResult = .success(LifecycleBootstrap.challenge)
        try execute(restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.apple.attestations.count, 0)
    }

    func testAppCodeAtTokenChallengeDoesNotCreateRegistrationRetirementPolicy() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let refusal = policyError("app_not_allowed")
        harness.bootstrap.tokenChallengeResult = .failure(refusal)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(60)
        harness.bootstrap.tokenChallengeResult = .success(LifecycleBootstrap.challenge)
        XCTAssertEqual(harness.identity.state?.requiresUserAction, false)
        XCTAssertNil(harness.identity.state?.recovery)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testLegacyPolicyRefusalRequiresUserProbeBeforeReplacingKnownBinding() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let original = try XCTUnwrap(harness.identity.state?.identity)
        harness.identity.state = NovaAuthInstallationState(
            version: 1, context: context, requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: original.clientID, keyID: original.keyID, registration: .retired(.policyRefused)
            )
        )
        let auth = harness.makeAuth()
        _ = try auth.activate(origin: harness.origin)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
    }

    func testUserGateSurvivesFailedIdentitySaveAndRetry() throws {
        let harness = try LifecycleHarness()
        let (auth, _) = try harness.registered()
        try auth.reset()
        let context = try XCTUnwrap(auth.currentContext)
        harness.identity.failSave = true
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
        harness.identity.failSave = false
        _ = try auth.activate(origin: harness.origin)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    private func policyError(_ code: String) -> NovaAuthError {
        .bootstrap(NovaAuthServerError(statusCode: 403, code: code, requestID: nil, retryAfter: nil))
    }
}
