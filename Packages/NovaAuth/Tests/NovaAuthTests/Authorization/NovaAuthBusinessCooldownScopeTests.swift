import XCTest
@testable import NovaAuth

final class NovaAuthBusinessCooldownScopeTests: LifecycleTestCase {
    func testIssuerUncoded500BlocksBothFamilies() throws {
        try assertScope(status: 500, shared: true)
    }

    func testIssuerUncoded502BlocksOnlyFailingFamily() throws {
        try assertScope(status: 502, shared: false)
    }

    func testIssuerUncoded503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, shared: false)
    }

    func testIssuerUncoded504BlocksOnlyFailingFamily() throws {
        try assertScope(status: 504, shared: false)
    }

    func testIssuerDomain500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "queue_over_capacity", shared: false)
    }

    func testIssuerDomain503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, code: "queue_over_capacity", shared: false)
    }

    func testIssuerBittensorDomain503LeavesAnalyticsAvailable() throws {
        try assertScope(status: 503, code: "dataset_unavailable", shared: false, analyticsFails: false)
    }

    func testIssuer429BlocksBothFamilies() throws {
        try assertScope(status: 429, shared: true)
    }

    func testIssuerExplicit503AuthUnavailableBlocksBothFamilies() throws {
        try assertScope(status: 503, code: "attestation_unavailable", shared: true)
    }

    func testIssuerAuthUnavailableAt500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "attestation_unavailable", shared: false)
    }
}

private extension NovaAuthBusinessCooldownScopeTests {
    func assertScope(
        status: Int,
        code: String? = nil,
        shared: Bool,
        analyticsFails: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let original = try XCTUnwrap(harness.tokens.load())
        let analytics = try harness.request(context: context, method: .post, body: Data("{}".utf8))
        let bittensor = try harness.request(context: context)
        let failing = analyticsFails ? analytics : bittensor
        let healthy = analyticsFails ? bittensor : analytics
        let body = code.map { Data("{\"error\":{\"code\":\"\($0)\",\"message\":\"retry\"}}".utf8) } ?? Data()
        harness.http.handler = { request, completion in
            completion(Result {
                if request.url?.path == failing.path {
                    return try LifecycleHTTP.response(
                        request: request, status: status, headers: ["Retry-After": "20"], body: body
                    )
                }
                return try LifecycleHTTP.response(request: request)
            })
        }
        defer { harness.http.handler = nil }
        let response = try execute(auth.createResponseWrapper(for: failing, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(response.response.statusCode, status, file: file, line: line)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        if shared {
            assertError(
                .cooldown(retryAfter: 20), auth.createResponseWrapper(for: healthy, beforeSend: {}),
                on: harness.callers, file: file, line: line
            )
        } else {
            let healthyResponse = try execute(auth.createResponseWrapper(for: healthy, beforeSend: {}), on: harness.callers)
            XCTAssertEqual(healthyResponse.response.statusCode, 200, file: file, line: line)
        }
        assertError(
            .cooldown(retryAfter: 20), auth.createResponseWrapper(for: failing, beforeSend: {}),
            on: harness.callers, file: file, line: line
        )
        XCTAssertEqual(
            harness.http.requests.compactMap { $0.url?.path },
            shared ? [failing.path] : [failing.path, healthy.path], file: file, line: line
        )
        XCTAssertEqual(
            Set(harness.http.requests.compactMap { $0.value(forHTTPHeaderField: "Authorization") }),
            ["Bearer " + original.accessToken], file: file, line: line
        )
        XCTAssertEqual(try harness.tokens.load(), original, file: file, line: line)
        XCTAssertTrue(harness.bootstrap.tokens.isEmpty, file: file, line: line)
        XCTAssertTrue(harness.apple.assertions.isEmpty, file: file, line: line)
    }
}
