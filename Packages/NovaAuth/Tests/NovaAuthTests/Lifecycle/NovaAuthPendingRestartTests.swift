import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthPendingRestartTests: LifecycleTestCase {
    private let unknownClient = NovaAuthError.bootstrap(NovaAuthServerError(
        statusCode: 401, code: "unknown_client", requestID: nil, retryAfter: nil
    ))

    func testSameBootRestartPreservesSevenProbesAndRemainingCooldown() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        harness.bootstrap.tokenChallengeResult = .failure(unknownClient)
        for delay in [0.0, 1, 2, 4, 8, 16, 30] {
            harness.clock.advance(delay)
            assertError(unknownClient, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        }
        let original = try pendingState(harness)
        XCTAssertEqual(original.unknownResponseCount, 7)
        harness.clock.advance(1)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.cooldown(retryAfter: 29), restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 7)
        XCTAssertEqual(try pendingState(harness), original)
        harness.clock.advance(29)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 8)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.unrecoverableRegistration))
        harness.clock.advance(31)
        assertError(.cooldown(retryAfter: 29), restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testRestartCannotRefreshOriginalUncertaintyWindow() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        harness.bootstrap.tokenChallengeResult = .failure(unknownClient)
        let start = try pendingState(harness).startedAt
        assertError(unknownClient, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        harness.clock.advance(119)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(unknownClient, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(try pendingState(harness).startedAt, start)
        harness.clock.advance(2)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 3)
        XCTAssertEqual(harness.apple.attestations.count, 0)
    }

    func testSentProbePersistsBackoffButOnlyObservedUnknownReplySpendsBudget() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        let response = LifecyclePending<NovaAuthChallenge>()
        let sent = expectation(description: "probe sent")
        response.onStart = { sent.fulfill() }
        harness.bootstrap.onTokenChallenge = response.start
        let first = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(first.allOperations, waitUntilFinished: false)
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(try pendingState(harness).unknownResponseCount, 0)
        XCTAssertEqual(try pendingState(harness).cooldown.deadline?.continuousSeconds, 101)
        first.cancel()
        response.resolve(.failure(unknownClient))
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.cooldown(retryAfter: 1), restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        harness.bootstrap.onTokenChallenge = nil
        harness.bootstrap.tokenChallengeResult = .failure(unknownClient)
        harness.clock.advance(1)
        assertError(unknownClient, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(try pendingState(harness).unknownResponseCount, 1)
        XCTAssertEqual(try pendingState(harness).cooldown.deadline?.continuousSeconds, 103)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 2)
    }

    func testQueuedCancelledProbeDoesNotSpendPersistedBudget() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        harness.bootstrapQueue.isSuspended = true
        defer { harness.bootstrapQueue.isSuspended = false }
        let queued = expectation(description: "probe queued")
        harness.bootstrap.onTokenChallengeCreated = { queued.fulfill() }
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [queued], timeout: 5)
        wrapper.cancel()
        XCTAssertEqual(try pendingState(harness).unknownResponseCount, 0)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testProbeStorageFailurePreventsSendAndCannotSpendOnlyInMemory() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        harness.identity.failSave = true
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(try pendingState(harness).unknownResponseCount, 0)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testPendingCountCannotBlockARecoveredBindingBeforeReceivingItsResponse() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        var cooldown = NovaAuthCooldown()
        let now = try harness.clock.now()
        for _ in 0 ..< 8 { cooldown.fail(now: now, random: 0) }
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        try auth.gate.novaAuthLocked {
            try auth.setIdentity(NovaAuthInstallationIdentity(
                clientID: identity.clientID, keyID: identity.keyID,
                registration: .registrationPending(NovaAuthPendingRegistration(startedAt: now, unknownResponseCount: 8, cooldown: cooldown))
            ), context: context)
        }
        harness.clock.advance(31)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        try execute(restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testRetryAfterSurvivesRestartWithoutResettingExponentialSequence() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try pending(harness)
        let throttled = NovaAuthError.bootstrap(NovaAuthServerError(statusCode: 429, code: nil, requestID: nil, retryAfter: 60))
        harness.bootstrap.tokenChallengeResult = .failure(throttled)
        assertError(throttled, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.cooldown(retryAfter: 60), restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        harness.clock.advance(60)
        harness.bootstrap.tokenChallengeResult = .failure(unknownClient)
        assertError(unknownClient, restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(try pendingState(harness).unknownResponseCount, 1)
        XCTAssertEqual(try pendingState(harness).cooldown.deadline?.continuousSeconds, 162)
    }

    private func pending(_ harness: LifecycleHarness) throws -> (NovaAuth, NovaAuthContext) {
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        try auth.gate.novaAuthLocked {
            try auth.setIdentity(NovaAuthInstallationIdentity(
                clientID: identity.clientID, keyID: identity.keyID,
                registration: .registrationPending(NovaAuthPendingRegistration(startedAt: try harness.clock.now()))
            ), context: context)
        }
        return (auth, context)
    }

    private func pendingState(_ harness: LifecycleHarness) throws -> NovaAuthPendingRegistration {
        guard case let .registrationPending(pending) = harness.identity.state?.identity?.registration else {
            throw NovaAuthError.invalidResponse
        }
        return pending
    }
}
