import XCTest
@testable import NovaAuth

final class NovaAuthPolicyRetryTests: LifecycleTestCase {
    func testAppRefusalAtRegisterRequiresUserReplacementAndNeverProbesRefusedIdentity() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let refusal = refusal("app_not_allowed")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationRefused))
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
        XCTAssertNil(harness.identity.state?.recovery?.policyRetryDelay)
        XCTAssertEqual(harness.identity.state?.requiresUserAction, false)
        for _ in 0 ..< 3 {
            harness.clock.advance(100_000)
            let restarted = harness.makeAuth()
            _ = try restarted.activate(origin: harness.origin)
            assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        }
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(refusal, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 2)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 2)
    }

    func testBindingRefusalAtRegisterChargesOnlyRetirement() throws {
        let harness = try LifecycleHarness()
        let refusal = refusal("binding_not_allowed")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationRefused))
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
        XCTAssertNil(harness.identity.state?.recovery?.policyRetryDelay)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 0)
    }

    func testTokenChallengePolicyLadderSurvivesRestartAndKeepsIdentity() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        var (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let refusal = refusal("binding_not_allowed")
        harness.bootstrap.tokenChallengeResult = .failure(refusal)
        for delay in [60.0, 600, 600] {
            assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            auth = harness.makeAuth()
            _ = try auth.activate(origin: harness.origin)
            assertError(.cooldown(retryAfter: delay), auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            harness.clock.advance(delay)
        }
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 0)
        XCTAssertNil(harness.identity.state?.recovery?.recreationDelay)
        XCTAssertNil(harness.identity.state?.recovery?.proofRetryDelay)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testTokenPolicyRefusalChargesOnlyPolicyDelay() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let original = harness.identity.state?.identity
        let refusal = refusal("binding_not_allowed")
        harness.bootstrap.onToken = { $0(.failure(refusal)) }
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.policyRetryDelay?.failures, 1)
        XCTAssertNil(harness.identity.state?.recovery?.recreationDelay)
        XCTAssertNil(harness.identity.state?.recovery?.proofRetryDelay)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 0)
    }

    private func refusal(_ code: String) -> NovaAuthError {
        .bootstrap(NovaAuthServerError(statusCode: 403, code: code, requestID: nil, retryAfter: nil))
    }
}
