import XCTest
@testable import NovaAuth

final class NovaAuthBusinessCooldownScopeTests: LifecycleTestCase {
    func testIssuerUncoded500BlocksBothFamilies() throws {
        try assertScope(status: 500, shared: true)
    }

    func testReaderUncoded500BlocksBothFamilies() throws {
        try assertScope(status: 500, shared: true, useReader: true)
    }

    func testIssuerUncoded502BlocksOnlyFailingFamily() throws {
        try assertScope(status: 502, shared: false)
    }

    func testReaderUncoded502BlocksOnlyFailingFamily() throws {
        try assertScope(status: 502, shared: false, useReader: true)
    }

    func testIssuerUncoded503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, shared: false)
    }

    func testReaderUncoded503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, shared: false, useReader: true)
    }

    func testIssuerUncoded504BlocksOnlyFailingFamily() throws {
        try assertScope(status: 504, shared: false)
    }

    func testReaderUncoded504BlocksOnlyFailingFamily() throws {
        try assertScope(status: 504, shared: false, useReader: true)
    }

    func testIssuerDomain500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "queue_over_capacity", shared: false)
    }

    func testReaderDomain500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "queue_over_capacity", shared: false, useReader: true)
    }

    func testIssuerDomain503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, code: "queue_over_capacity", shared: false)
    }

    func testReaderDomain503BlocksOnlyFailingFamily() throws {
        try assertScope(status: 503, code: "queue_over_capacity", shared: false, useReader: true)
    }

    func testIssuerBittensorDomain503LeavesAnalyticsAvailable() throws {
        try assertScope(status: 503, code: "dataset_unavailable", shared: false, analyticsFails: false)
    }

    func testReaderBittensorDomain503LeavesAnalyticsAvailable() throws {
        try assertScope(status: 503, code: "dataset_unavailable", shared: false, useReader: true, analyticsFails: false)
    }

    func testIssuer429BlocksBothFamilies() throws {
        try assertScope(status: 429, shared: true)
    }

    func testReader429BlocksBothFamilies() throws {
        try assertScope(status: 429, shared: true, useReader: true)
    }

    func testIssuerExplicit503AuthUnavailableBlocksBothFamilies() throws {
        try assertScope(status: 503, code: "attestation_unavailable", shared: true)
    }

    func testReaderExplicit503AuthUnavailableBlocksBothFamilies() throws {
        try assertScope(status: 503, code: "attestation_unavailable", shared: true, useReader: true)
    }

    func testIssuerAuthUnavailableAt500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "attestation_unavailable", shared: false)
    }

    func testReaderAuthUnavailableAt500BlocksOnlyFailingFamily() throws {
        try assertScope(status: 500, code: "attestation_unavailable", shared: false, useReader: true)
    }
}

private extension NovaAuthBusinessCooldownScopeTests {
    func assertScope(
        status: Int,
        code: String? = nil,
        shared: Bool,
        useReader: Bool = false,
        analyticsFails: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        let client: NovaAuthClientProtocol = useReader ? harness.makeReader() : auth
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
        let response = try execute(client.createResponseWrapper(for: failing, beforeSend: {}), on: harness.callers)
        XCTAssertEqual(response.response.statusCode, status, file: file, line: line)
        let admission = client.createAdmissionWrapper(in: context, intent: .background)
        if shared, useReader {
            assertError(.cooldown(retryAfter: 20), admission, on: harness.callers, file: file, line: line)
        } else {
            try execute(admission, on: harness.callers)
        }
        if shared {
            assertError(
                .cooldown(retryAfter: 20), client.createResponseWrapper(for: healthy, beforeSend: {}),
                on: harness.callers, file: file, line: line
            )
        } else {
            let healthyResponse = try execute(client.createResponseWrapper(for: healthy, beforeSend: {}), on: harness.callers)
            XCTAssertEqual(healthyResponse.response.statusCode, 200, file: file, line: line)
        }
        assertError(
            .cooldown(retryAfter: 20), client.createResponseWrapper(for: failing, beforeSend: {}),
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
