import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthRegistrationRecoveryTests: LifecycleTestCase {
    func testLostRegistrationSuccessProbesWithSameIdentityAndNeverAttestsAgain() throws {
        let harness = try LifecycleHarness()
        harness.bootstrap.registrationResult = .failure(NovaAuthError.transport(.networkConnectionLost))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.transport(.networkConnectionLost), auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        guard case .registrationPending = identity.registration else { return XCTFail("Expected pending binding") }
        harness.clock.advance(2)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        try execute(restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.clientID, identity.clientID)
        XCTAssertEqual(harness.identity.state?.identity?.keyID, identity.keyID)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
        XCTAssertEqual(harness.apple.attestations.count, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 1)
    }

    func testAppleUnavailableRetriesExactHashAndKeyOnlyWhileChallengeIsValid() throws {
        let harness = try LifecycleHarness()
        harness.apple.attest = { .createWithError(NovaAuthAppAttestError.serverUnavailable) }
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        harness.clock.advance(2)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations[0].0, harness.apple.attestations[1].0)
        XCTAssertEqual(harness.apple.attestations[0].1, harness.apple.attestations[1].1)
        XCTAssertEqual(harness.bootstrap.registrationChallenges, 1)
        harness.clock.advance(70)
        harness.apple.attest = nil
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.unrecoverableRegistration))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations.count, 2)
    }

    func testUnknownAppleInFlightOnRestartRetiresWithoutRepeatingAttest() throws {
        let harness = try LifecycleHarness()
        let (unused, context) = try harness.registered()
        _ = unused
        let prior = try XCTUnwrap(harness.identity.state?.identity)
        let attempt = NovaAuthRegistrationAttempt(
            challenge: LifecycleBootstrap.challenge.challenge,
            contentType: "application/json",
            clientDataHash: Data(repeating: 2, count: 32),
            startedAt: try harness.clock.now()
        )
        harness.identity.state = NovaAuthInstallationState(
            version: 1,
            context: context,
            requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(clientID: prior.clientID, keyID: prior.keyID, registration: .appleInFlight(attempt))
        )
        let auth = harness.makeAuth()
        _ = try auth.activate(origin: harness.origin)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 0)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testPendingUnknownClientIsBoundedThenLaterBackgroundDemandRecovers() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        let original = harness.identity.state?.identity?.clientID
        let error = NovaAuthError.bootstrap(NovaAuthServerError(statusCode: 401, code: "unknown_client", requestID: nil, retryAfter: nil))
        harness.bootstrap.tokenChallengeResult = .failure(error)
        assertError(error, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.clientID, original)
        harness.clock.advance(121)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.unrecoverableRegistration))
        XCTAssertEqual(harness.apple.keys, 0)
        harness.clock.advance(31)
        assertError(.cooldown(retryAfter: 29), auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(29)
        harness.bootstrap.tokenChallengeResult = .success(LifecycleBootstrap.challenge)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertNotEqual(harness.identity.state?.identity?.clientID, original)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testPendingUnknownClientRetiresOnEighthProbeWithoutTimerPolling() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try pending(harness)
        let error = NovaAuthError.bootstrap(NovaAuthServerError(statusCode: 401, code: "unknown_client", requestID: nil, retryAfter: nil))
        harness.bootstrap.tokenChallengeResult = .failure(error)
        for delay in [0.0, 1, 2, 4, 8, 16, 30] {
            harness.clock.advance(delay)
            assertError(error, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        }
        harness.clock.advance(30)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 8)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testRebootedPendingCanRecoverKnownBindingButRetiresUnknownBinding() throws {
        for known in [true, false] {
            let harness = try LifecycleHarness()
            let (auth, context) = try pending(harness)
            harness.clock.reboot()
            if known {
                try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
                XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
            } else {
                harness.bootstrap.tokenChallengeResult = .failure(NovaAuthError.bootstrap(
                    NovaAuthServerError(statusCode: 401, code: "unknown_client", requestID: nil, retryAfter: nil)))
                assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
            }
            XCTAssertEqual(harness.apple.attestations.count, 0)
        }
    }

    func testProofFailurePreservesBindingWhilePolicyAndMissingKeyHaveDistinctRetirements() throws {
        for code in ["invalid_proof", "app_not_allowed", "binding_not_allowed"] {
            let harness = try LifecycleHarness()
            let (auth, context) = try harness.registered()
            let server = NovaAuthServerError(statusCode: 403, code: code, requestID: nil, retryAfter: nil)
            harness.bootstrap.onToken = { $0(.failure(NovaAuthError.bootstrap(server))) }
            assertError(.bootstrap(server), auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
            XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
            XCTAssertEqual(harness.identity.state?.requiresUserAction, code == "app_not_allowed")
            XCTAssertEqual(harness.apple.keys, 0)
        }
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.lostKey))
    }

    private func pending(_ harness: LifecycleHarness) throws -> (NovaAuth, NovaAuthContext) {
        let (_, context) = try harness.registered()
        let prior = try XCTUnwrap(harness.identity.state?.identity)
        harness.identity.state = NovaAuthInstallationState(
            version: 1,
            context: context,
            requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: prior.clientID,
                keyID: prior.keyID,
                registration: .registrationPending(NovaAuthPendingRegistration(startedAt: try harness.clock.now()))
            )
        )
        let auth = harness.makeAuth()
        _ = try auth.activate(origin: harness.origin)
        return (auth, context)
    }
}
