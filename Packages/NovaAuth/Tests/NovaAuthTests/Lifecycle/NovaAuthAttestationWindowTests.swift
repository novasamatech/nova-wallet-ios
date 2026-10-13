import XCTest
import Operation_iOS
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthAttestationWindowTests: LifecycleTestCase {
    func testDeferredAttemptAtExactlyFortySecondsCallsApple() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try deferred(harness)
        harness.clock.advance(40)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 1)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testDeferredAttemptAtFortyPointZeroZeroOneSecondsRetiresBeforeApple() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try deferred(harness)
        harness.clock.advance(40.001)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 0)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
        harness.clock.advance(100_000)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testRebootedDeferredAttemptRetiresBeforeApple() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try deferred(harness)
        harness.clock.reboot()
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
    }

    func testNegativeAgeDeferredAttemptRetiresBeforeApple() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try deferred(harness)
        harness.clock.advance(-1)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
    }

    func testAppleCompletionAtSixtySecondsRetiresBeforeRegister() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try deferred(harness)
        harness.clock.advance(40)
        harness.apple.attest = {
            CompoundOperationWrapper(targetOperation: ClosureOperation {
                harness.clock.advance(20)
                return Data([1, 2, 3])
            })
        }
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
    }

    func testDeferredRetryWithinBudgetPreservesKeyAndHash() throws {
        let harness = try LifecycleHarness()
        harness.apple.attest = { .createWithError(NovaAuthAppAttestError.serverUnavailable) }
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        harness.clock.advance(40)
        harness.apple.attest = nil
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.attestations.count, 2)
        XCTAssertEqual(harness.apple.attestations[0].0, harness.apple.attestations[1].0)
        XCTAssertEqual(harness.apple.attestations[0].1, harness.apple.attestations[1].1)
        XCTAssertEqual(harness.bootstrap.registrationChallenges, 1)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    private func deferred(_ harness: LifecycleHarness) throws -> (NovaAuth, NovaAuthContext) {
        let (auth, context) = try harness.registered()
        let attempt = NovaAuthRegistrationAttempt(
            challenge: LifecycleBootstrap.challenge.challenge,
            contentType: "application/json",
            clientDataHash: Data(repeating: 2, count: 32),
            startedAt: try harness.clock.now()
        )
        try auth.gate.novaAuthLocked {
            try auth.setRegistration(.appleDeferred(attempt), flight: NovaAuthIssuanceFlight(context: context, sponsored: false))
        }
        return (auth, context)
    }
}
