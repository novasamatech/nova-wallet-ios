import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthNativeAttestationAgeTests: LifecycleTestCase {
    func testQueuedAttestationAgesPastFortySecondsWithoutNativeInvocation() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let service = CountingDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service)
        let auth = try deferred(harness, appAttest: adapter)
        let context = try XCTUnwrap(auth.state?.context)
        harness.clock.advance(39)
        harness.bootstrapQueue.isSuspended = true
        defer { harness.bootstrapQueue.isSuspended = false }
        let completed = demand(auth, context: context, expected: .userActionRequired)
        drain(harness.ownerQueue)
        guard case .appleInFlight = harness.identity.state?.identity?.registration else {
            return XCTFail("Expected queued attestation")
        }
        harness.clock.advance(1.001)
        harness.bootstrapQueue.isSuspended = false
        wait(for: [completed], timeout: 5)
        XCTAssertEqual(service.attestationCalls, 0)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.deadline?.continuousSeconds, 200.001)
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
        harness.clock.advance(60)
        let restarted = harness.makeAuth(appAttest: adapter)
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(service.keyCalls, 0)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
    }

    func testQueuedAttestationExecutesNativelyAtExactlyFortySeconds() throws {
        let harness = try LifecycleHarness()
        let service = CountingDeviceCheck()
        let auth = try deferred(harness, appAttest: NovaAuthDeviceCheckService(service: service))
        let context = try XCTUnwrap(auth.state?.context)
        harness.clock.advance(39)
        harness.bootstrapQueue.isSuspended = true
        defer { harness.bootstrapQueue.isSuspended = false }
        let completed = demand(auth, context: context)
        drain(harness.ownerQueue)
        harness.clock.advance(1)
        harness.bootstrapQueue.isSuspended = false
        wait(for: [completed], timeout: 5)
        XCTAssertEqual(service.attestationCalls, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 1)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
        XCTAssertNil(harness.identity.state?.recovery)
    }

    func testContextChangedAtNativeGuardCannotRetireNewGeneration() throws {
        let harness = try LifecycleHarness()
        let service = CountingDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service)
        let boundary = AttestationBoundaryAdapter(base: adapter)
        let auth = try deferred(harness, appAttest: boundary)
        let context = try XCTUnwrap(auth.state?.context)
        boundary.beforeGuard = {
            _ = try auth.activate(origin: NovaAuthOrigin("https://next.example.com"))
            harness.clock.advance(61)
        }
        harness.bootstrapQueue.isSuspended = true
        defer { harness.bootstrapQueue.isSuspended = false }
        let completed = demand(auth, context: context, expected: .generationChanged)
        drain(harness.ownerQueue)
        let childCompleted = observeCompletion(of: try XCTUnwrap(harness.bootstrapQueue.operations.first))
        harness.bootstrapQueue.isSuspended = false
        wait(for: [completed, childCompleted], timeout: 5)
        drain(harness.ownerQueue)
        XCTAssertEqual(service.attestationCalls, 0)
        XCTAssertEqual(auth.state?.context.generation, context.generation + 1)
        XCTAssertEqual(auth.state?.context.origin, try NovaAuthOrigin("https://next.example.com"))
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertNil(harness.identity.state?.recovery)
        XCTAssertTrue(harness.identity.state?.requiresUserAction == true)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
    }

    func testNativeAttestationFinishingAtSixtySecondsRetiresWithoutRegistering() throws {
        let harness = try LifecycleHarness()
        let service = CountingDeviceCheck()
        let auth = try deferred(harness, appAttest: NovaAuthDeviceCheckService(service: service))
        let context = try XCTUnwrap(auth.state?.context)
        harness.clock.advance(40)
        service.onAttestation = { harness.clock.advance(20) }
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(service.attestationCalls, 1)
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.registrationAbandoned))
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
    }

    private func demand(
        _ auth: NovaAuth,
        context: NovaAuthContext,
        expected: NovaAuthError? = nil
    ) -> XCTestExpectation {
        let completed = expectation(description: "admission completed")
        auth.demand(context: context, intent: .background, cancellation: NovaAuthCancellation()) { result in
            switch result {
            case .success:
                XCTAssertNil(expected)
            case let .failure(error):
                if let expected { XCTAssertEqual(error as? NovaAuthError, expected) }
                else { XCTFail("Unexpected admission failure: \(error)") }
            }
            completed.fulfill()
        }
        return completed
    }

    private func deferred(_ harness: LifecycleHarness, appAttest: NovaAuthAppAttestProtocol) throws -> NovaAuth {
        let attempt = NovaAuthRegistrationAttempt(
            challenge: LifecycleBootstrap.challenge.challenge, contentType: "application/json",
            clientDataHash: Data(repeating: 2, count: 32), startedAt: try harness.clock.now()
        )
        harness.identity.state = NovaAuthInstallationState(
            version: 1, context: NovaAuthContext(origin: harness.origin, generation: 1), requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: FoundationFixture.clientID, keyID: FoundationFixture.keyID, registration: .appleDeferred(attempt)
            )
        )
        let auth = harness.makeAuth(appAttest: appAttest)
        _ = try auth.activate(origin: harness.origin)
        return auth
    }
}

private final class AttestationBoundaryAdapter: NovaAuthAppAttestProtocol {
    let base: NovaAuthDeviceCheckService
    var beforeGuard: (() throws -> Void)?
    var isSupported: Bool { base.isSupported }
    init(base: NovaAuthDeviceCheckService) { self.base = base }
    func isBusy(keyID: String) -> Bool { base.isBusy(keyID: keyID) }
    func createKeyWrapper() -> CompoundOperationWrapper<String> { base.createKeyWrapper() }
    func createAssertionWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data> {
        base.createAssertionWrapper(keyID: keyID, clientDataHash: clientDataHash)
    }

    func createAttestationWrapper(
        keyID: String,
        clientDataHash: Data,
        beforeAttest: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Data> {
        base.createAttestationWrapper(keyID: keyID, clientDataHash: clientDataHash, beforeAttest: { [self] in
            try beforeGuard?()
            try beforeAttest()
        })
    }
}
