import XCTest
import Operation_iOS
import NovaAnalytics
@testable import NovaAuth
@testable import novawallet

final class BittensorAuthorizedTransportTests: XCTestCase {
    override func setUp() { super.setUp(); HostAuthURLProtocol.reset() }

    private func makeTransport() throws -> (BittensorAuthorizedTransport, HostAuthHarness, HostAuthProvider) {
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let provider = try HostAuthProvider(client: harness.client)
        return (BittensorAuthorizedTransport(provider: provider, operationQueue: OperationQueue()), harness, provider)
    }

    private func request(_ method: BittensorApiRequest.Method = .get, body: Data? = nil) -> BittensorApiRequest {
        BittensorApiRequest(
            method: method,
            path: method == .post ? "/operations/search" : "/subnets",
            pathTemplate: "/subnets",
            queryItems: [],
            jsonBody: body,
            intent: .userInitiated
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "authorized response")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private var invalidToken: HostAuthURLProtocol.Reply {
        .init(
            status: 401,
            headers: ["WWW-Authenticate": "Bearer error=\"invalid_token\"", "Content-Type": "application/json"],
            body: Data(#"{"error":{"code":"invalid_token","message":"expired"}}"#.utf8)
        )
    }

    func testGetUsesProfile3AndOneBearerAfterFourBootstrapRequests() throws {
        let (transport, harness, _) = try makeTransport()
        _ = try run(transport.createResponseWrapper(for: request()))
        let requests = HostAuthURLProtocol.requests
        XCTAssertEqual(requests.map { $0.url!.path }, [
            "/v1/attestation/profile-3/challenges", "/v1/attestation/profile-3/register",
            "/v1/attestation/profile-3/token-challenges", "/v1/attestation/profile-3/tokens",
            "/v1/bittensor/profile-3/subnets"
        ])
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer host-bearer-1")
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(harness.apple.assertions, 1)
        XCTAssertEqual(harness.apple.attestations, 1)
    }

    func testPostPreservesExistingPathAndExactBytes() throws {
        let (transport, _, _) = try makeTransport()
        let body = Data(#"{"accountSubject":"account","page":1}"#.utf8)
        _ = try run(transport.createResponseWrapper(for: request(.post, body: body)))
        let sent = try XCTUnwrap(HostAuthURLProtocol.businessRequests.first)
        XCTAssertEqual(sent.url?.path, "/v1/bittensor/operations/search")
        XCTAssertEqual(sent.httpBody, body)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testInvalidTokenRetriesOnceWithReplacementBearer() throws {
        let (transport, harness, _) = try makeTransport()
        let refusal = invalidToken
        HostAuthURLProtocol.business = { request in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer host-bearer-1" ? refusal : .init(status: 200)
        }
        _ = try run(transport.createResponseWrapper(for: request()))
        XCTAssertEqual(
            HostAuthURLProtocol.businessRequests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer host-bearer-1", "Bearer host-bearer-2"]
        )
        XCTAssertEqual(harness.apple.assertions, 2)
        XCTAssertEqual(harness.apple.attestations, 1)
    }

    func testApprovedPostRecoveryReplaysIdenticalBytesOnce() throws {
        let (transport, _, _) = try makeTransport()
        let refusal = invalidToken
        HostAuthURLProtocol.business = { request in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer host-bearer-1" ? refusal : .init(status: 200)
        }
        let body = Data(#"{"accountSubject":"account","page":1}"#.utf8)
        _ = try run(transport.createResponseWrapper(for: request(.post, body: body)))
        XCTAssertEqual(HostAuthURLProtocol.businessRequests.map(\.httpBody), [body, body])
    }

    func testSecondInvalidTokenFailsWithoutThirdBusinessRequest() throws {
        let (transport, harness, _) = try makeTransport()
        let refusal = invalidToken
        HostAuthURLProtocol.business = { _ in refusal }
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request())))
        XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 2)
        XCTAssertEqual(harness.apple.assertions, 2)
        XCTAssertNil(try harness.tokens.load())
    }

    func testGeneric401DoesNotRenewOrReplay() throws {
        let (transport, harness, _) = try makeTransport()
        HostAuthURLProtocol.business = { _ in .init(status: 401) }
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request()))) { error in
            guard case let BittensorApiError.server(status, _, _) = error else { return XCTFail("Expected server authorization failure") }
            XCTAssertEqual(status, 401)
        }
        XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 1)
        XCTAssertEqual(harness.apple.assertions, 1)
    }

    func testGraderPreservesTransportAndRecoverableProtocolFailures() {
        if case let .transport(error) = BittensorAuthorizedResponseGrader.map(URLError(.notConnectedToInternet)) {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        } else { XCTFail("Expected original transport classification") }
        if case .attestationUnavailable = BittensorAuthorizedResponseGrader.map(NovaAuthError.invalidResponse) {}
        else { XCTFail("Malformed protocol response must remain retryable") }
        if case .generationStale = BittensorAuthorizedResponseGrader.map(NovaAuthError.generationChanged) {}
        else { XCTFail("Expected stale generation") }
        if case let .transport(error) = BittensorAuthorizedResponseGrader.map(NovaAuthError.cancelled) {
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        } else { XCTFail("Expected cancellation") }
    }

    func testOnlyExplicitBootstrapPolicyRefusalBlamesAttestationPolicy() {
        for code in [nil, "unknown_error", "binding_not_allowed"] as [String?] {
            let error = NovaAuthError.bootstrap(NovaAuthServerError(statusCode: 403, code: code, requestID: "request", retryAfter: nil))
            let mapped = BittensorAuthorizedResponseGrader.map(error)
            if code == "binding_not_allowed" {
                if case .attestationRejected = mapped {} else { XCTFail("Expected conclusive policy rejection") }
            } else {
                if case .attestationUnavailable = mapped {} else { XCTFail("An uncoded edge error is not device rejection") }
            }
        }
    }

    func testPostUnknownTransportOutcomeDoesNotReplay() throws {
        let (transport, harness, _) = try makeTransport()
        HostAuthURLProtocol.business = { _ in .init(status: 0) }
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request(.post, body: Data("{}".utf8)))))
        XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 1)
        XCTAssertEqual(harness.apple.assertions, 1)
    }

    func testOriginRateLimitSuppressesFollowingDemandWithoutRenewal() throws {
        let (transport, harness, _) = try makeTransport()
        HostAuthURLProtocol.business = { _ in .init(status: 429, headers: ["Retry-After": "60"]) }
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request())))
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request())))
        XCTAssertEqual(HostAuthURLProtocol.businessRequests.count, 1)
        XCTAssertEqual(harness.apple.assertions, 1)
    }

    func testBootstrapServerFailureMapsToUnavailableWithoutBusinessRequest() throws {
        let (transport, _, _) = try makeTransport()
        HostAuthURLProtocol.bootstrapFailure = .init(status: 503)
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request())))
        XCTAssertTrue(HostAuthURLProtocol.businessRequests.isEmpty)
    }

    func testUnsupportedDeviceSendsNothing() throws {
        let (transport, harness, _) = try makeTransport()
        harness.apple.isSupported = false
        XCTAssertThrowsError(try run(transport.createResponseWrapper(for: request())))
        XCTAssertTrue(HostAuthURLProtocol.requests.isEmpty)
    }

    func testMixedAnalyticsAndBittensorDemandUsesSameClientAndSingleIssuance() throws {
        let (transport, harness, provider) = try makeTransport()
        let auth = try run(AnalyticsAuthAdapter(provider: provider).createAuthWrapper())
        XCTAssertTrue(auth.client === harness.client)
        let analytics = AnalyticsUploadOperationFactory(auth: auth)
        let first = transport.createResponseWrapper(for: request())
        let second = analytics.createUploadWrapper(body: Data("{}".utf8), beforeSend: {})
        let completed = expectation(description: "mixed demand")
        completed.expectedFulfillmentCount = 2
        first.targetOperation.completionBlock = { completed.fulfill() }
        second.targetOperation.completionBlock = { completed.fulfill() }
        let queue = OperationQueue()
        queue.addOperations(first.allOperations + second.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        _ = try first.targetOperation.extractNoCancellableResultData()
        try second.targetOperation.extractNoCancellableResultData()
        XCTAssertEqual(harness.apple.assertions, 1)
        XCTAssertEqual(
            Set(HostAuthURLProtocol.businessRequests.compactMap { $0.value(forHTTPHeaderField: "Authorization") }),
            ["Bearer host-bearer-1"]
        )
    }
}
