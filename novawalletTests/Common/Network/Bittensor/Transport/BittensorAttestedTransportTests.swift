import XCTest
@testable import novawallet
import Cuckoo
import NovaAppAttest
import Operation_iOS

private final class BittensorStubURLProtocol: URLProtocol {
    struct Reply {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    private static let lock = NSLock()
    private static var replies: [Reply] = []
    private static var delay: TimeInterval = 0
    private static var requests: [(request: URLRequest, body: Data)] = []
    private static var events: [String] = []

    static func reset(replies newReplies: [Reply], delay newDelay: TimeInterval = 0) {
        lock.lock()
        replies = newReplies
        delay = newDelay
        requests = []
        events = []
        lock.unlock()
    }

    static func record(event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    static var recordedEvents: [String] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    static var recordedRequests: [(request: URLRequest, body: Data)] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append((request, Self.readBody(of: request)))
        Self.events.append("send")
        let reply = Self.replies.isEmpty ? Reply(statusCode: 500, headers: [:], body: Data()) : Self.replies.removeFirst()
        let delay = Self.delay
        Self.lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let url = request.url else { return }

            Self.record(event: "response")

            let response = HTTPURLResponse(
                url: url,
                statusCode: reply.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: reply.headers
            )!

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}

final class BittensorAttestedTransportTests: XCTestCase {
    private let baseURL = URL(string: "https://bittensor.test/")!
    private var signedTargets: [AttestationRequestTarget] = []
    private var signedBodies: [Data] = []

    override func setUp() {
        super.setUp()
        signedTargets = []
        signedBodies = []
    }

    func testGetSignsTheQueryFreeTargetAndSendsNoContentTypeWithTheFourHeaders() throws {
        BittensorStubURLProtocol.reset(replies: [makeReply(statusCode: 200, body: Data("{}".utf8))])

        let provider = makeProvider(clientIds: ["client-a"])

        let request = BittensorApiRequest(
            method: .get,
            path: "/subnets/12/yields/alpha",
            pathTemplate: "/subnets/{netuid}/yields/alpha",
            queryItems: [URLQueryItem(name: "page", value: "2"), URLQueryItem(name: "pageSize", value: "50")],
            jsonBody: nil
        )

        _ = try fetch(makeTransport(provider: provider).createResponseWrapper(for: request))

        let sent = try XCTUnwrap(BittensorStubURLProtocol.recordedRequests.first)
        let signedTarget = try XCTUnwrap(signedTargets.first)

        XCTAssertEqual(
            sent.request.url?.absoluteString,
            "https://bittensor.test/v1/bittensor/subnets/12/yields/alpha?page=2&pageSize=50"
        )
        XCTAssertEqual(sent.request.httpMethod, "GET")
        XCTAssertNil(sent.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(sent.body.isEmpty)
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "X-Attestation-Profile"), "2")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "X-Client-Id"), "client-a")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "X-Challenge"), "challenge-1")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "X-App-Attest-Assertion"), "assertion-1")
        XCTAssertEqual(signedTarget.url, sent.request.url)
        XCTAssertEqual(signedTarget.method, "GET")
        XCTAssertEqual(signedTarget.path, "/v1/bittensor/subnets/12/yields/alpha")
        XCTAssertEqual(signedTarget.contentType, "")
        XCTAssertEqual(signedBodies, [Data()])
    }

    func testPostSendsExactlyTheSignedBodyBytes() throws {
        BittensorStubURLProtocol.reset(replies: [makeReply(statusCode: 200, body: Data("{}".utf8))])

        let provider = makeProvider(clientIds: ["client-a"])
        let jsonBody = Data(#"{"accountSubject":"5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY","page":2}"#.utf8)

        let request = BittensorApiRequest(
            method: .post,
            path: "/rewards/search",
            pathTemplate: "/rewards/search",
            queryItems: [],
            jsonBody: jsonBody
        )

        _ = try fetch(makeTransport(provider: provider).createResponseWrapper(for: request))

        let sent = try XCTUnwrap(BittensorStubURLProtocol.recordedRequests.first)
        let signedTarget = try XCTUnwrap(signedTargets.first)

        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(sent.body, jsonBody)
        XCTAssertEqual(signedBodies, [jsonBody])
        XCTAssertEqual(signedTarget.method, "POST")
        XCTAssertEqual(signedTarget.contentType, "application/json")
    }

    func testInvalidProofRetriesOnceWithFreshHeadersAndSucceeds() throws {
        BittensorStubURLProtocol.reset(replies: [
            makeReply(statusCode: 401, body: makeErrorBody(code: "invalid_proof")),
            makeReply(statusCode: 200, body: Data("retried".utf8))
        ])

        let provider = makeProvider(clientIds: ["client-a", "client-a"])

        let response = try fetch(makeTransport(provider: provider).createResponseWrapper(for: makeGetRequest()))

        let challenges = BittensorStubURLProtocol.recordedRequests.map {
            $0.request.value(forHTTPHeaderField: "X-Challenge")
        }

        XCTAssertEqual(response.body, Data("retried".utf8))
        XCTAssertEqual(challenges, ["challenge-1", "challenge-2"])
        verify(provider, times(2)).createSignedHeadersWrapper(target: any(), bodyClosure: any())
    }

    func testUnknownClientRetriesWithTheNewClientIdAfterMarkingTheSignedOneUnattested() throws {
        BittensorStubURLProtocol.reset(replies: [
            makeReply(statusCode: 401, body: makeErrorBody(code: "unknown_client")),
            makeReply(statusCode: 200, body: Data("registered".utf8))
        ])

        let provider = makeProvider(clientIds: ["client-a", "client-b"])

        let response = try fetch(makeTransport(provider: provider).createResponseWrapper(for: makeGetRequest()))

        let clientIds = BittensorStubURLProtocol.recordedRequests.map {
            $0.request.value(forHTTPHeaderField: "X-Client-Id")
        }

        XCTAssertEqual(response.body, Data("registered".utf8))
        XCTAssertEqual(clientIds, ["client-a", "client-b"])
        verify(provider, times(1)).markUnattested(ifCurrentClientId: "client-a")
    }

    func testUnknownClientFailsWithoutRetryWhenTheClientIdIsUnchanged() {
        BittensorStubURLProtocol.reset(replies: [
            makeReply(statusCode: 401, body: makeErrorBody(code: "unknown_client"), requestId: "req-unknown")
        ])

        let provider = makeProvider(clientIds: ["client-a", "client-a"])

        let error = fetchError(makeTransport(provider: provider).createResponseWrapper(for: makeGetRequest()))

        guard case let .attestationFailure(requestId) = error else {
            return XCTFail("Unexpected result: \(String(describing: error))")
        }

        XCTAssertEqual(requestId, "req-unknown")
        XCTAssertEqual(BittensorStubURLProtocol.recordedRequests.count, 1)
        verify(provider, times(1)).markUnattested(ifCurrentClientId: "client-a")
        verify(provider, times(2)).createSignedHeadersWrapper(target: any(), bodyClosure: any())
    }

    func testBindingNotAllowedLatchesRejectionForLaterCalls() {
        BittensorStubURLProtocol.reset(replies: [
            makeReply(statusCode: 403, body: makeErrorBody(code: "binding_not_allowed"), requestId: "req-forbidden")
        ])

        let provider = makeProvider(clientIds: ["client-a"])
        let transport = makeTransport(provider: provider)

        let firstError = fetchError(transport.createResponseWrapper(for: makeGetRequest()))
        let secondError = fetchError(transport.createResponseWrapper(for: makeGetRequest()))

        guard
            case let .attestationRejected(firstRequestId) = firstError,
            case let .attestationRejected(secondRequestId) = secondError else {
            return XCTFail("Unexpected results: \(String(describing: firstError)), \(String(describing: secondError))")
        }

        XCTAssertEqual(firstRequestId, "req-forbidden")
        XCTAssertNil(secondRequestId)
        verify(provider, times(1)).createSignedHeadersWrapper(target: any(), bodyClosure: any())
    }

    func testProviderServerErrorMapsToAttestationUnavailable() {
        BittensorStubURLProtocol.reset(replies: [])

        let provider = MockBackendAttestationProviderProtocol()

        stub(provider) { stub in
            when(stub.createSignedHeadersWrapper(target: any(), bodyClosure: any())).then { _, _ in
                CompoundOperationWrapper.createWithError(BackendAttestationError.serverError(statusCode: 500))
            }
        }

        let error = fetchError(makeTransport(provider: provider).createResponseWrapper(for: makeGetRequest()))

        guard case .attestationUnavailable = error else {
            return XCTFail("Unexpected result: \(String(describing: error))")
        }

        XCTAssertTrue(BittensorStubURLProtocol.recordedRequests.isEmpty)
    }

    func testConcurrentCallsNeverOverlapSignAndSend() throws {
        BittensorStubURLProtocol.reset(
            replies: [
                makeReply(statusCode: 200, body: Data("first".utf8)),
                makeReply(statusCode: 200, body: Data("second".utf8))
            ],
            delay: 0.2
        )

        let transport = makeTransport(provider: makeProvider(clientIds: ["client-a", "client-a"], signDelay: 0.1))

        let firstWrapper = transport.createResponseWrapper(for: makeGetRequest())
        let secondWrapper = transport.createResponseWrapper(for: makeGetRequest())

        run([firstWrapper, secondWrapper])

        XCTAssertNoThrow(try firstWrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNoThrow(try secondWrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertEqual(
            BittensorStubURLProtocol.recordedEvents,
            ["sign", "send", "response", "sign", "send", "response"]
        )
    }

    func testSeventhSignAttemptWithinAMinuteFailsRateLimited() throws {
        BittensorStubURLProtocol.reset(
            replies: (0 ..< 7).map { _ in makeReply(statusCode: 200, body: Data("{}".utf8)) }
        )

        let provider = makeProvider(clientIds: Array(repeating: "client-a", count: 7))
        let transport = makeTransport(provider: provider)

        for _ in 0 ..< BittensorSignBudget.maxAttempts {
            _ = try fetch(transport.createResponseWrapper(for: makeGetRequest()))
        }

        let error = fetchError(transport.createResponseWrapper(for: makeGetRequest()))

        guard case .rateLimited = error else {
            return XCTFail("Unexpected result: \(String(describing: error))")
        }

        XCTAssertEqual(BittensorStubURLProtocol.recordedRequests.count, BittensorSignBudget.maxAttempts)
        verify(provider, times(BittensorSignBudget.maxAttempts)).createSignedHeadersWrapper(
            target: any(),
            bodyClosure: any()
        )
    }

    private func makeTransport(provider: MockBackendAttestationProviderProtocol) -> BittensorAttestedTransport {
        let holder = MockBittensorAttestationHolderProtocol()
        let context = BittensorAttestationContext(baseURL: baseURL, provider: provider)

        stub(holder) { stub in
            when(stub.createContextWrapper()).then {
                CompoundOperationWrapper.createWithResult(context)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BittensorStubURLProtocol.self]

        return BittensorAttestedTransport(
            holder: holder,
            executor: BittensorAttestedRequestExecutor(timeProvider: { 1000 }),
            session: URLSession(configuration: configuration),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func makeProvider(
        clientIds: [String],
        signDelay: TimeInterval = 0
    ) -> MockBackendAttestationProviderProtocol {
        let provider = MockBackendAttestationProviderProtocol()
        let lock = NSLock()
        var signCount = 0

        stub(provider) { stub in
            when(stub.createSignedHeadersWrapper(target: any(), bodyClosure: any())).then { target, bodyClosure in
                lock.lock()
                signCount += 1
                let number = signCount
                self.signedTargets.append(target)
                self.signedBodies.append((try? bodyClosure()) ?? Data("unreadable".utf8))
                lock.unlock()

                BittensorStubURLProtocol.record(event: "sign")

                let headers: [AttestationHeaderKey: String] = [
                    .profile: "2",
                    .clientId: clientIds[min(number, clientIds.count) - 1],
                    .challenge: "challenge-\(number)",
                    .appAttestAssertion: "assertion-\(number)"
                ]

                let operation = AsyncClosureOperation<[AttestationHeaderKey: String]?> { completion in
                    DispatchQueue.global().asyncAfter(deadline: .now() + signDelay) {
                        completion(.success(headers))
                    }
                }

                return CompoundOperationWrapper(targetOperation: operation)
            }

            when(stub.markUnattested(ifCurrentClientId: any())).thenDoNothing()
        }

        return provider
    }

    private func makeGetRequest() -> BittensorApiRequest {
        BittensorApiRequest(
            method: .get,
            path: "/subnets/64/validators",
            pathTemplate: "/subnets/{netuid}/validators",
            queryItems: [],
            jsonBody: nil
        )
    }

    private func makeReply(
        statusCode: Int,
        body: Data,
        requestId: String = "req-id"
    ) -> BittensorStubURLProtocol.Reply {
        BittensorStubURLProtocol.Reply(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json", "X-Request-ID": requestId],
            body: body
        )
    }

    private func makeErrorBody(code: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"refused"}}"#.utf8)
    }

    private func run(_ wrappers: [CompoundOperationWrapper<BittensorApiRawResponse>]) {
        let completed = expectation(description: "Attested calls finished")
        completed.expectedFulfillmentCount = wrappers.count

        wrappers.forEach { wrapper in
            wrapper.targetOperation.completionBlock = { completed.fulfill() }
        }

        OperationQueue().addOperations(wrappers.flatMap(\.allOperations), waitUntilFinished: false)

        wait(for: [completed], timeout: 10)
    }

    private func fetch(
        _ wrapper: CompoundOperationWrapper<BittensorApiRawResponse>
    ) throws -> BittensorApiRawResponse {
        run([wrapper])

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchError(_ wrapper: CompoundOperationWrapper<BittensorApiRawResponse>) -> BittensorApiError? {
        do {
            _ = try fetch(wrapper)

            return nil
        } catch {
            return error as? BittensorApiError
        }
    }
}
