import XCTest
@testable import NovaAuth

final class NovaAuthRecoveryAdmissionTests: LifecycleTestCase {
    func testUsableBearerSurvivesRetiredIdentityRecreationDelay() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        try auth.gate.novaAuthLocked {
            try auth.retire(.lostKey, flight: NovaAuthIssuanceFlight(context: context, sponsored: false))
        }
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertNotNil(try harness.tokens.load())
    }

    func testUsableBearerDuringPolicyDelayDoesNotStartEarlyRefresh() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(455)
        try setRecovery(NovaAuthRecoveryState(policyRetryDelay: cooldown(harness)), auth: auth)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testUsableBearerDuringProofDelayDoesNotStartEarlyRefresh() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(455)
        try setRecovery(NovaAuthRecoveryState(proofRetryDelay: cooldown(harness)), auth: auth)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testUsableBearerDuringIssuanceCooldownDoesNotStartEarlyRefresh() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(455)
        try auth.gate.novaAuthLocked { auth.issuanceCooldown = try cooldown(harness) }
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testOriginCooldownPreservesBearerAdmissionAndBlocksEarlyRefreshAndBusinessSend() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        harness.clock.advance(455)
        try auth.gate.novaAuthLocked { auth.originCooldown = try cooldown(harness) }
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        let request = try harness.request(context: context)
        assertError(.cooldown(retryAfter: 60), auth.createResponseWrapper(for: request, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(harness.http.requests.count, 0)
        XCTAssertNotNil(try harness.tokens.load())
    }

    func testRecreationDelayDoesNotBlockRegisteredIdentityIssuance() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        try setRecovery(NovaAuthRecoveryState(recreationDelay: cooldown(harness)), auth: auth)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testSuccessfulBearerInstallationClearsEveryRecoveryField() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let delay = try cooldown(harness)
        try setRecovery(NovaAuthRecoveryState(
            recreationDelay: delay, policyRetryDelay: delay, proofRetryDelay: delay, backgroundRecreations: 2
        ), auth: auth)
        harness.clock.advance(60)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertNil(harness.identity.state?.recovery)
    }

    func testContextReplacementDropsEveryRecoveryField() throws {
        let harness = try LifecycleHarness()
        let (auth, _) = try harness.registered()
        let delay = try cooldown(harness)
        try setRecovery(NovaAuthRecoveryState(
            recreationDelay: delay, policyRetryDelay: delay, proofRetryDelay: delay, backgroundRecreations: 2
        ), auth: auth)
        try auth.reset()
        XCTAssertNil(harness.identity.state?.recovery)
    }

    private func cooldown(_ harness: LifecycleHarness) throws -> NovaAuthCooldown {
        var cooldown = NovaAuthCooldown()
        cooldown.failLadder(now: try harness.clock.now(), random: 0, caps: 86400)
        return cooldown
    }

    private func setRecovery(_ recovery: NovaAuthRecoveryState, auth: NovaAuth) throws {
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = recovery
            try auth.persist(state)
        }
    }
}
