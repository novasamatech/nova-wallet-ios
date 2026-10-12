import XCTest
import Operation_iOS
@testable import NovaAuth

final class NovaAuthHTTPTests: XCTestCase {
    override func tearDown() {
        FoundationURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testReadAndPostUseSeparateNativePoliciesAndNoCookieHeaders() throws {
        let transport = NovaAuthHTTPTransport(protocolClasses: [FoundationURLProtocol.self])
        let observed = expectation(description: "read and post")
        observed.expectedFulfillmentCount = 2
        FoundationURLProtocol.setHandler { stub in
            XCTAssertNil(stub.request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertFalse(stub.request.httpShouldHandleCookies)
            let isRead = stub.request.httpMethod == "GET"
            XCTAssertEqual(stub.request.cachePolicy, isRead ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData)
            stub.succeed()
            observed.fulfill()
        }
        let get = try request()
        _ = try executeFoundation(transport.createResponseWrapper(for: get, kind: .businessRead, beforeSend: {}))
        var post = try request(path: "/v1/analytics/events")
        post.httpMethod = "POST"
        post.httpBody = Data("{}".utf8)
        post.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try executeFoundation(transport.createResponseWrapper(for: post, kind: .businessPost, beforeSend: {}))
        wait(for: [observed], timeout: 1)
    }

    func testSendFenceAndForbiddenRequestFailBeforeTaskStarts() throws {
        let transport = NovaAuthHTTPTransport(protocolClasses: [FoundationURLProtocol.self])
        FoundationURLProtocol.setHandler { _ in XCTFail("must not start a task") }
        XCTAssertThrowsError(try executeFoundation(transport.createResponseWrapper(
            for: request(),
            kind: .businessRead,
            beforeSend: { throw NovaAuthError.generationChanged }
        ))) {
            XCTAssertEqual($0 as? NovaAuthError, .generationChanged)
        }
        var invalid = try request()
        invalid.setValue("sensitive", forHTTPHeaderField: "Cookie")
        XCTAssertThrowsError(try executeFoundation(
            transport
                .createResponseWrapper(for: invalid, kind: .businessRead, beforeSend: {})
        ))
        invalid = try request(path: "/v1/bittensor/profile-3/subnets/%31/validators")
        XCTAssertThrowsError(try executeFoundation(
            transport
                .createResponseWrapper(for: invalid, kind: .businessRead, beforeSend: {})
        ))
    }

    func testAllRedirectsAreRejectedIncludingSameOrigin() throws {
        for destination in ["https://example.com/next", "https://foreign.example/next"] {
            let delegate = NovaAuthHTTPDelegate()
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let request = try request()
            let task = session.dataTask(with: request)
            let call = NovaAuthHTTPCall(request: request, kind: .businessRead, timeout: 1)
            let finished = expectation(description: "redirect refused")
            call.prepare(task: task) { result in
                if case let .failure(error) = result {
                    XCTAssertEqual(error as? NovaAuthError, .invalidResponse)
                } else { XCTFail("Redirect unexpectedly succeeded") }
                finished.fulfill()
            }
            delegate.insert(call, for: task, session: session)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": destination]
            ))
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: try XCTUnwrap(URL(string: destination)))
            ) { XCTAssertNil($0) }
            wait(for: [finished], timeout: 1)
        }
    }

    func testBoundedHTTPCallTimesOutAndCancelsOnlyItsOwnTask() throws {
        let started = expectation(description: "task started")
        let cancelled = expectation(description: "task cancelled")
        FoundationURLProtocol.setHandler { stub in
            stub.onStop = { cancelled.fulfill() }
            started.fulfill()
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FoundationURLProtocol.self]
        let delegate = NovaAuthHTTPDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let request = try request()
        let task = session.dataTask(with: request)
        let call = NovaAuthHTTPCall(request: request, kind: .businessRead, timeout: 0.05)
        let finished = expectation(description: "bounded failure")
        call.prepare(task: task) { result in
            if case let .failure(error) = result {
                XCTAssertEqual(error as? NovaAuthError, .transport(.timedOut))
            } else { XCTFail("Hung task unexpectedly succeeded") }
            finished.fulfill()
        }
        delegate.insert(call, for: task, session: session)
        try call.resume()
        wait(for: [started, finished, cancelled], timeout: 2)
    }

    func testPublicNativeCacheAdmissionRejectsIdentityHeadersAndVary() throws {
        XCTAssertTrue(try cacheAllowed(["Cache-Control": "public, max-age=60, must-revalidate",
                                        "Date": "Mon, 12 Oct 2026 00:00:00 GMT", "Age": "5"]))
        for headers in [
            ["Cache-Control": "no-store"], ["Cache-Control": "private, max-age=60"],
            ["Cache-Control": "public, private=\"identity\""],
            ["Cache-Control": "public, max-age=60", "Set-Cookie": "value"],
            ["Cache-Control": "public, max-age=60", "X-Client-ID": "value"],
            ["Cache-Control": "public, max-age=60", "Vary": "Accept-Encoding, Authorization"],
            ["Cache-Control": "public, max-age=60", "Vary": "Cookie"],
            ["Cache-Control": "public, max-age=60", "Vary": "X-Installation-ID"],
            ["Cache-Control": "public, max-age=60", "Vary": "*"]
        ] { XCTAssertFalse(try cacheAllowed(headers)) }
        XCTAssertFalse(try cacheAllowed(["Cache-Control": "public, max-age=60"], status: 401))
    }

    private func cacheAllowed(_ headers: [String: String], status: Int = 200) throws -> Bool {
        let response = try FoundationFixture.response("{}", status: status, headers: headers).response
        return NovaAuthHTTPDelegate.isPublicCacheResponse(CachedURLResponse(response: response, data: Data("{}".utf8)))
    }

    private func request(path: String = "/v1/bittensor/profile-3/subnets") throws -> URLRequest {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com" + path)))
        request.httpMethod = "GET"
        request.setValue("Bearer synthetic-token", forHTTPHeaderField: "Authorization")
        return request
    }
}

private final class FoundationURLProtocol: URLProtocol {
    private static let mutex = NSLock()
    private static var handler: ((FoundationURLProtocol) -> Void)?
    var onStop: (() -> Void)?
    static func setHandler(_ handler: ((FoundationURLProtocol) -> Void)?) {
        mutex.lock(); self.handler = handler; mutex.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.mutex.lock(); let handler = Self.handler; Self.mutex.unlock()
        handler?(self)
    }

    override func stopLoading() { onStop?() }
    func succeed() {
        guard let url = request.url, let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Cache-Control": "no-store"]
        ) else {
            client?.urlProtocol(self, didFailWithError: NovaAuthError.invalidResponse)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
