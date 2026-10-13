import XCTest
@testable import NovaAuth

final class NovaAuthProofRetryTests: LifecycleTestCase {
    func testTokenProofDelaySurvivesRelaunchAndRetryUsesFreshChallengeAndAssertion() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let failure = proofFailure()
        harness.bootstrap.onToken = { $0(.failure(failure)) }
        assertError(failure, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        harness.clock.advance(59)
        assertError(.cooldown(retryAfter: 1), restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        harness.clock.advance(1)
        harness.bootstrap.tokenChallengeResult = .success(NovaAuthChallenge(
            challenge: Data(repeating: 2, count: 32).base64EncodedString().replacingOccurrences(of: "=", with: ""),
            issuedAt: 1000,
            expiresAt: 1060
        ))
        assertError(failure, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 2)
        XCTAssertEqual(harness.apple.assertions.count, 2)
        XCTAssertNotEqual(harness.bootstrap.tokens[0].challenge, harness.bootstrap.tokens[1].challenge)
        XCTAssertNotEqual(harness.apple.assertions[0].1, harness.apple.assertions[1].1)
        XCTAssertEqual(harness.apple.assertions[0].0, harness.apple.assertions[1].0)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.proofRetryDelay?.failures, 2)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 0)
        XCTAssertNil(harness.identity.state?.recovery?.recreationDelay)
        XCTAssertNil(harness.identity.state?.recovery?.policyRetryDelay)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testTokenChallengeInvalidProofDoesNotChargeProofDelay() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let failure = proofFailure()
        harness.bootstrap.tokenChallengeResult = .failure(failure)
        assertError(failure, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertNil(harness.identity.state?.recovery)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.apple.assertions.count, 0)
    }

    func testMixedPolicyAndProofFailuresPreserveRecreationTierAndBudget() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        var recreation = NovaAuthCooldown()
        recreation.failLadder(now: try harness.clock.now(), random: 0, caps: 86400)
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = NovaAuthRecoveryState(recreationDelay: recreation, backgroundRecreations: 1)
            try auth.persist(state)
        }
        let policy = NovaAuthError.bootstrap(NovaAuthServerError(statusCode: 403, code: "binding_not_allowed", requestID: nil, retryAfter: nil))
        harness.bootstrap.tokenChallengeResult = .failure(policy)
        assertError(policy, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(60)
        harness.bootstrap.tokenChallengeResult = .success(LifecycleBootstrap.challenge)
        let proof = proofFailure()
        harness.bootstrap.onToken = { $0(.failure(proof)) }
        assertError(proof, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(60)
        harness.bootstrap.tokenChallengeResult = .failure(policy)
        assertError(policy, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.recovery?.policyRetryDelay?.failures, 2)
        XCTAssertEqual(harness.identity.state?.recovery?.proofRetryDelay?.failures, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay, recreation)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    private func proofFailure() -> NovaAuthError {
        .bootstrap(NovaAuthServerError(statusCode: 401, code: "invalid_proof", requestID: nil, retryAfter: nil))
    }
}
