import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthLifecycleDiagnosticsTests: LifecycleTestCase {
    func testLostKeyRetirementEmitsReasonAndMaximumLocalRecoveryDelayWithoutIdentity() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 1
        let (_, context) = try harness.registered()
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        let logged = expectation(description: "assertion failure logged after retirement")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=assertion") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = NovaAuthRecoveryState(recreationDelay: priorDelay(caps: 86400))
            try auth.persist(state)
        }
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=identityRetired reason=lostKey"))
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=cooldown scope=recreation retryAfter=95040"))
        let messages = logger.messages.joined(separator: "\n")
        XCTAssertFalse(messages.contains(identity.clientID))
        XCTAssertFalse(messages.contains(try XCTUnwrap(identity.keyID)))
        XCTAssertFalse(messages.contains(LifecycleBootstrap.challenge.challenge))
    }

    func testBindingRefusalEmitsPolicyScopeWithoutUntrustedMetadata() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (_, context) = try harness.registered()
        let logged = expectation(description: "binding failure logged after policy delay")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=tokenChallenge") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        let error = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 403, code: "binding_not_allowed", requestID: "SECRET\nHEADER", retryAfter: 95040
        ))
        harness.bootstrap.tokenChallengeResult = .failure(error)
        assertError(error, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=cooldown scope=policy retryAfter=60"))
        XCTAssertFalse(logger.messages.joined().contains("SECRET"))
        XCTAssertFalse(logger.messages.joined().contains("retryAfter=95040"))
    }

    func testInvalidProofEmitsLongLocalProofDelay() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (_, context) = try harness.registered()
        let logged = expectation(description: "proof failure logged after persisted delay")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=token reason=") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = NovaAuthRecoveryState(proofRetryDelay: priorDelay(caps: 3600))
            try auth.persist(state)
        }
        let error = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "invalid_proof", requestID: "proof-request", retryAfter: nil
        ))
        harness.bootstrap.onToken = { $0(.failure(error)) }
        assertError(error, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=cooldown scope=proof retryAfter=3600"))
        XCTAssertFalse(logger.messages.joined().contains(harness.bootstrap.tokenResult.accessToken))
        XCTAssertFalse(logger.messages.joined().contains("transition=identityRetired"))
    }

    func testIssuanceRetryAfterEmitsBoundedSharedScope() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let logged = expectation(description: "issuance throttle logged")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=tokenChallenge") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        let error = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 429, code: "SECRET_SERVER_DETAIL", requestID: "request-429", retryAfter: 905
        ))
        harness.bootstrap.tokenChallengeResult = .failure(error)
        assertError(error, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=cooldown scope=shared retryAfter=905"))
        XCTAssertFalse(logger.messages.joined().contains("SECRET_SERVER_DETAIL"))
    }

    func testPendingProbeFailureEmitsSharedScope() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (_, context) = try harness.registered()
        let logged = expectation(description: "pending probe failure logged")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=tokenChallenge") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        try auth.gate.novaAuthLocked {
            try auth.setRegistration(
                .registrationPending(NovaAuthPendingRegistration(startedAt: try harness.clock.now())),
                flight: NovaAuthIssuanceFlight(context: context, sponsored: false)
            )
        }
        harness.bootstrap.tokenChallengeResult = .failure(NovaAuthError.transport(.timedOut))
        assertError(.transport(.timedOut), auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertTrue(logger.messages.contains("NovaAuth transition=cooldown scope=shared retryAfter=1"))
    }

    func testRepeatedFailedStateWritesEmitOneStorageFailureBeforeRepair() throws {
        let harness = try LifecycleHarness()
        let repaired = expectation(description: "storage repair logged")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0 == "NovaAuth transition=storageRecovery" { repaired.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        harness.identity.failSave = true
        XCTAssertThrowsError(try auth.activate(origin: harness.origin))
        XCTAssertThrowsError(try auth.activate(origin: harness.origin))
        harness.identity.failSave = false
        _ = try auth.activate(origin: harness.origin)
        wait(for: [repaired], timeout: 5)
        XCTAssertEqual(logger.messages, ["NovaAuth transition=storageFailed", "NovaAuth transition=storageRecovery"])
        XCTAssertEqual(logger.levels, ["warning", "warning"])
    }

    func testFailedRetirementEmitsStorageFailureWithoutClaimingPersistedRetirement() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let logged = expectation(description: "dirty retirement failure logged")
        let logger = AuthRecordingLogger()
        logger.onMessage = { if $0.contains("failure phase=assertion") { logged.fulfill() } }
        let auth = harness.makeAuth(logger: logger)
        _ = try auth.activate(origin: harness.origin)
        harness.apple.assert = {
            harness.identity.failSave = true
            return .createWithError(NovaAuthAppAttestError.invalidKey)
        }
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        wait(for: [logged], timeout: 5)
        XCTAssertEqual(logger.messages.filter { $0 == "NovaAuth transition=storageFailed" }.count, 1)
        XCTAssertFalse(logger.messages.joined().contains("transition=identityRetired"))
    }

    private func priorDelay(caps: TimeInterval) -> NovaAuthCooldown {
        var cooldown = NovaAuthCooldown()
        for _ in 0 ..< 3 {
            cooldown.failLadder(now: NovaAuthTime(bootID: "boot-old", continuousSeconds: 1), random: 0, caps: caps)
        }
        return cooldown
    }
}
