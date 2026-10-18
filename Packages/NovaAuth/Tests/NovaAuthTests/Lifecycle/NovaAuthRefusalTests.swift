@testable import NovaAuth
import XCTest

final class NovaAuthRefusalTests: XCTestCase {
    func testRefusedRegistrationKeepsTheClientIDAndTheNextUserDemandAttestsAFreshKey() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 403, body: FakeAuthServer.error("app_not_allowed")))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal(403, "app_not_allowed"), auth.createAdmissionWrapper(in: context))
        XCTAssertNil(auth.state?.identity?.keyID)
        harness.clock.advance(2)
        assertError(refusal(403, "app_not_allowed"), auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.random.clientIDs, 1)
        XCTAssertEqual(harness.apple.keys, 2)
        XCTAssertEqual(harness.server.count("/register"), 2)
    }

    func testCodelessRegistrationFailureKeepsThePendingKeyForTheLaterProbe() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 403))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal(403, nil), auth.createAdmissionWrapper(in: context))
        XCTAssertNotNil(auth.state?.identity?.keyID)
        harness.clock.advance(2)
        try execute(auth.createAdmissionWrapper(in: context))
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.apple.attestations, 1)
        XCTAssertEqual(harness.server.count("/register"), 1)
    }

    func testBackgroundDemandWaitsForTheGrowingRefusalDelayWhileUserDemandRetriesAtOnce() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 401, body: FakeAuthServer.error("attestation_failed")))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal(401, "attestation_failed"), auth.createAdmissionWrapper(in: context))
        harness.clock.advance(2)
        try assertError(
            .cooldown(retryAfter: 3598),
            auth.createResponseWrapper(for: harness.request(context, analytics: true), beforeSend: {})
        )
        try assertError(
            refusal(401, "attestation_failed"),
            auth.createResponseWrapper(for: harness.request(context), beforeSend: {})
        )
        harness.clock.advance(3600)
        try assertError(
            .cooldown(retryAfter: 18000),
            auth.createResponseWrapper(for: harness.request(context, analytics: true), beforeSend: {})
        )
        harness.clock.advance(18000)
        try assertError(
            refusal(401, "attestation_failed"),
            auth.createResponseWrapper(for: harness.request(context, analytics: true), beforeSend: {})
        )
        XCTAssertEqual(harness.server.count("/register"), 3)
    }

    func testAppVersionChangeResetsTheRefusalDelay() throws {
        let harness = try AuthHarness()
        harness.server.registration = .success(.init(status: 403, body: FakeAuthServer.error("binding_not_allowed")))
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(refusal(403, "binding_not_allowed"), auth.createAdmissionWrapper(in: context))
        harness.clock.advance(2)
        let relaunched = try harness.relaunch(version: "2")
        try assertError(
            refusal(403, "binding_not_allowed"),
            relaunched.createResponseWrapper(for: harness.request(context, analytics: true), beforeSend: {})
        )
        XCTAssertEqual(harness.server.count("/register"), 2)
    }
}

private func refusal(_ status: Int, _ code: String?) -> NovaAuthError {
    .bootstrap(NovaAuthServerError(statusCode: status, code: code, requestID: nil, retryAfter: nil))
}
