import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthRegistrationTests: LifecycleTestCase {
    func testConstructionAndActivationAreLazyThenOneIdentityServesAllDemand() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        XCTAssertNil(harness.identity.state)
        let context = try auth.activate(origin: harness.origin)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertEqual(harness.apple.keys, 0)
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        let identity = harness.identity.state?.identity
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, identity)
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations.count, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 1)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertEqual(identity?.registration, .registered)
    }

    func testUnsupportedCapabilityDoesNotCreateIdentityOrContactBootstrap() throws {
        let harness = try LifecycleHarness()
        harness.apple.isSupported = false
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.unsupported, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertEqual(harness.bootstrap.registrationChallenges, 0)
    }

    func testResetFencesAlreadyConstructedWrapperAndRequiresNewUserDemand() throws {
        let harness = try LifecycleHarness()
        let (auth, oldContext) = try harness.registered(withToken: true)
        let stale = auth.createAdmissionWrapper(in: oldContext, intent: .userInitiated)
        try auth.reset()
        let context = try XCTUnwrap(auth.currentContext)
        XCTAssertGreaterThan(context.generation, oldContext.generation)
        assertError(.generationChanged, stale, on: harness.callers)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertNil(try harness.tokens.load())
        try execute(auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testOriginChangeFencesOldContextAndClearsReadCache() throws {
        let harness = try LifecycleHarness()
        let (auth, oldContext) = try harness.registered(withToken: true)
        XCTAssertEqual(try auth.activate(origin: harness.origin), oldContext)
        let next = try auth.activate(origin: NovaAuthOrigin("https://new.example.com"))
        XCTAssertEqual(next.generation, oldContext.generation + 1)
        XCTAssertEqual(harness.http.cleared, 1)
        assertError(.generationChanged, auth.createAdmissionWrapper(in: oldContext, intent: .userInitiated), on: harness.callers)
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: next, intent: .background), on: harness.callers)
    }

    func testIdentityPersistenceFailureStopsBeforeApple() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        harness.identity.failSave = true
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testTokenFailureBeforeSendPreservesOriginalErrorWithoutIssuanceClockSample() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.bootstrap.tokenBeforeSendFailure = NovaAuthError.cancelled
        assertError(.cancelled, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testAdmissionReplacesRejectedBearerEvenWhenDeletingItFailed() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let rejected = try XCTUnwrap(harness.tokens.load())
        harness.tokens.failRemove = true
        auth.gate.novaAuthLocked { auth.rejectedCredentials.reject(rejected) }
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
        XCTAssertNotEqual(try harness.tokens.load()?.accessToken, rejected.accessToken)
    }
}
