import XCTest
@testable import NovaAuth

final class NovaAuthBusyKeyTests: LifecycleTestCase {
    func testBusyKeySkipsTokenChallengeAndPreservesIdentity() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        harness.apple.busyKeys.insert(try XCTUnwrap(identity.keyID))
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        XCTAssertEqual(harness.apple.assertions.count, 0)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.identity.state?.identity, identity)
        XCTAssertNil(harness.identity.state?.recovery)
    }

    func testNativeLeaseBlocksIssuanceAfterTimeoutUntilActualCallback() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let identity = try XCTUnwrap(harness.identity.state?.identity)
        let keyID = try XCTUnwrap(identity.keyID)
        let native = DelayedDeviceCheck()
        let service = NovaAuthDeviceCheckService(service: native, timeout: 0.02)
        XCTAssertThrowsError(try execute(service.createAssertionWrapper(
            keyID: keyID, clientDataHash: Data(repeating: 1, count: 32)
        ), on: harness.bootstrapQueue)) { XCTAssertEqual(String(describing: $0), "timedOut") }
        XCTAssertTrue(service.isBusy(keyID: keyID))
        let auth = harness.makeAuth(appAttest: service)
        _ = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(native.proofCount, 1)
        XCTAssertEqual(harness.identity.state?.identity, identity)
        try native.callback(at: 0)(Data([1, 2, 3]), nil)
        XCTAssertFalse(service.isBusy(keyID: keyID))
        native.automaticResponse = Data([4, 5, 6])
        harness.clock.advance(2)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(native.proofCount, 2)
        XCTAssertEqual(harness.identity.state?.identity, identity)
    }

    func testOtherNativeKeyLeaseDoesNotBlockCurrentIdentityIssuance() throws {
        let harness = try LifecycleHarness()
        let (_, context) = try harness.registered()
        let keyID = try XCTUnwrap(harness.identity.state?.identity?.keyID)
        let otherKey = Data(repeating: 99, count: 32).base64EncodedString()
        let native = DelayedDeviceCheck()
        let service = NovaAuthDeviceCheckService(service: native, timeout: 0.02)
        XCTAssertThrowsError(try execute(service.createAssertionWrapper(
            keyID: otherKey, clientDataHash: Data(repeating: 1, count: 32)
        ), on: harness.bootstrapQueue)) { XCTAssertEqual(String(describing: $0), "timedOut") }
        XCTAssertTrue(service.isBusy(keyID: otherKey))
        XCTAssertFalse(service.isBusy(keyID: keyID))
        native.automaticResponse = Data([4, 5, 6])
        let auth = harness.makeAuth(appAttest: service)
        _ = try auth.activate(origin: harness.origin)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 1)
        XCTAssertEqual(native.proofCount, 2)
        XCTAssertTrue(service.isBusy(keyID: otherKey))
        try native.callback(at: 0)(Data([1, 2, 3]), nil)
    }
}
