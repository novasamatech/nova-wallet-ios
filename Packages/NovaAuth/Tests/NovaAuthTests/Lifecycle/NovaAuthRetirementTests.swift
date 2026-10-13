import XCTest
@testable import NovaAuth

final class NovaAuthRetirementTests: LifecycleTestCase {
    func testPersistentRegistrationRefusalNeverRecreatesForBackgroundAfterRelaunch() throws {
        let harness = try LifecycleHarness()
        let refusal = registrationError(status: 401, code: "attestation_failed")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        for _ in 0 ..< 4 {
            harness.clock.advance(100_000)
            let restarted = harness.makeAuth()
            _ = try restarted.activate(origin: harness.origin)
            assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        }
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 1)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationRefused))
    }

    func testPersistentRegistrationRefusalCreatesExactlyOneKeyPerEligibleUserAction() throws {
        let harness = try LifecycleHarness()
        let refusal = registrationError(status: 401, code: "attestation_failed")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        for expectedKeys in 1 ... 4 {
            assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
            XCTAssertEqual(harness.apple.keys, expectedKeys)
            harness.clock.advance(100_000)
        }
        XCTAssertEqual(Set(harness.bootstrap.registrations.map(\.clientID)).count, 4)
    }

    func testFailedUserReplacementKeepsRefusalRestrictionAfterRelaunch() throws {
        let harness = try LifecycleHarness()
        let refusal = registrationError(status: 401, code: "attestation_failed")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        let retired = harness.identity.state?.identity
        harness.clock.advance(100_000)
        harness.apple.keyResult = .failure(NovaAuthAppAttestError.failure)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, retired)
        harness.clock.advance(100_000)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 2)
    }

    func testRegisterInvalidProofRetiresAsRegistrationRefusal() throws {
        let harness = try LifecycleHarness()
        let refusal = registrationError(status: 401, code: "invalid_proof")
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationRefused))
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }

    func testUncodedRegisterFourHundredRetiresAsRegistrationRefusal() throws {
        let harness = try LifecycleHarness()
        let refusal = registrationError(status: 400, code: nil)
        harness.bootstrap.registrationResult = .failure(refusal)
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationRefused))
    }

    func testLegacyAbandonedRegistrationStillRequiresUserAction() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let flight = NovaAuthIssuanceFlight(context: context, sponsored: false, intent: .background)
        try auth.gate.novaAuthLocked {
            try auth.setRegistration(.retired(.unrecoverableRegistration), flight: flight)
        }
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    private func registrationError(status: Int, code: String?) -> NovaAuthError {
        .bootstrap(NovaAuthServerError(statusCode: status, code: code, requestID: nil, retryAfter: nil))
    }
}
