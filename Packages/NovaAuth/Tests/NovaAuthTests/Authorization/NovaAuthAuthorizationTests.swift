import XCTest
@testable import NovaAuth

final class NovaAuthAuthorizationTests: XCTestCase {
    func testInvalidTokenReplaysOnceWithAFreshBearerThenEndsDenied() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        harness.server.business = { _ in
            .init(status: 401, headers: ["WWW-Authenticate": "Bearer error=\"invalid_token\""], body: FakeAuthServer.error("invalid_token"))
        }
        let request = try harness.request(context)
        assertError(.authorizationDenied(requestID: nil), auth.createResponseWrapper(for: request, beforeSend: {}))
        XCTAssertEqual(
            harness.server.businessRequests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer bearer-1", "Bearer bearer-2"]
        )
    }

    func testBittensorDatasetOutageLeavesAnalyticsAvailable() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        harness.server.business = { request in
            request.url?.path == "/v1/analytics/events"
                ? .init(status: 204)
                : .init(status: 503, headers: ["Retry-After": "20"], body: FakeAuthServer.error("dataset_unavailable"))
        }
        try execute(auth.createResponseWrapper(for: harness.request(context), beforeSend: {}))
        try execute(auth.createResponseWrapper(for: harness.request(context, analytics: true), beforeSend: {}))
        let retry = try harness.request(context)
        assertError(.cooldown(retryAfter: 20), auth.createResponseWrapper(for: retry, beforeSend: {}))
        XCTAssertEqual(harness.server.businessRequests.count, 2)
    }

    func testOriginThrottleBlocksAnalyticsAndBittensor() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        harness.server.business = { _ in .init(status: 429, headers: ["Retry-After": "20"]) }
        try execute(auth.createResponseWrapper(for: harness.request(context), beforeSend: {}))
        let analytics = try harness.request(context, analytics: true)
        assertError(.cooldown(retryAfter: 20), auth.createResponseWrapper(for: analytics, beforeSend: {}))
        XCTAssertEqual(harness.server.businessRequests.count, 1)
    }

    func testCompletedExchangeReleasesItsOperationsAndCallerClosure() throws {
        let harness = try AuthHarness()
        let (auth, context) = try registered(harness)
        let released = expectation(description: "caller closure released")
        try autoreleasepool {
            let witness = ReleaseWitness { released.fulfill() }
            let wrapper = auth.createResponseWrapper(for: try harness.request(context), beforeSend: {
                withExtendedLifetime(witness) {}
            })
            try execute(wrapper)
        }
        wait(for: [released], timeout: 5)
    }
}

private final class ReleaseWitness {
    let onRelease: () -> Void
    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }
}
