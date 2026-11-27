import XCTest
@testable import novawallet

/// Answers `/hang` never and any other path with 200 and the last path component as the body
private final class ConfigMirrorLoaderStubURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let url = request.url,
            url.lastPathComponent != "hang",
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else {
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(url.lastPathComponent.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ConfigMirrorLoaderTests: XCTestCase {
    private let expectationTimeout: TimeInterval = 10
    private let mutex = NSLock()
    private var events: [String: [String]] = [:]

    private lazy var loader: ConfigMirrorLoader = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConfigMirrorLoaderStubURLProtocol.self]

        return ConfigMirrorLoader(configuration: configuration)
    }()

    func testReportsResponseThenDataThenCompletionSeparatelyForEachRequest() {
        // when
        let completions = ["first", "second"].map { load($0).completion }

        wait(for: completions, timeout: expectationTimeout)

        // then
        XCTAssertEqual(recordedEvents(of: "first"), ["response 200", "data first", "completed 0"])
        XCTAssertEqual(recordedEvents(of: "second"), ["response 200", "data second", "completed 0"])
    }

    func testCompletesCancelledRequestWithCancellation() {
        // when
        let (task, completion) = load("hang")
        task.cancel()

        wait(for: [completion], timeout: expectationTimeout)

        // then
        XCTAssertEqual(recordedEvents(of: "hang"), ["completed \(NSURLErrorCancelled)"])
    }

    func testKeepsOutOfHttpCacheAnswersToRequestsThatIgnoreItAndAnswersRulesAreAgainst() throws {
        let url = try XCTUnwrap(URL(string: "https://loader.novatest/hang"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let proposedResponse = CachedURLResponse(response: response, data: Data("{}".utf8))

        let usable = ConfigMirrorLoadRules.mirror { _, data in data == proposedResponse.data }
        let unusable = ConfigMirrorLoadRules.mirror { _, data in data != proposedResponse.data }

        let cases: [(policy: URLRequest.CachePolicy, rules: ConfigMirrorLoadRules, isCached: Bool)] = [
            (.useProtocolCachePolicy, .original, true),
            (.returnCacheDataElseLoad, .original, true),
            (.reloadIgnoringLocalCacheData, .original, false),
            (.reloadIgnoringLocalAndRemoteCacheData, .original, false),
            (.useProtocolCachePolicy, usable, true),
            (.useProtocolCachePolicy, unusable, false),
            (.reloadIgnoringLocalCacheData, usable, false)
        ]

        for (index, testCase) in cases.enumerated() {
            // the request never ends, so the loader still knows its rules
            let task = loader.load(URLRequest(url: url, cachePolicy: testCase.policy), rules: testCase.rules) { _ in }
            let dataTask = try XCTUnwrap(task as? URLSessionDataTask)
            var cachedResponse: CachedURLResponse?

            loader.urlSession(.shared, dataTask: dataTask, willCacheResponse: proposedResponse) { cachedResponse = $0 }

            XCTAssertEqual(cachedResponse != nil, testCase.isCached, "\(index)")

            task.cancel()
        }
    }

    func testFollowsRedirectOnlyWhenRulesAllowIt() throws {
        let url = try XCTUnwrap(URL(string: "https://loader.novatest/hang"))
        let newRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://elsewhere.novatest/file.json")))
        let response = try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": "https://elsewhere.novatest/file.json"])
        )

        let cases: [(rules: ConfigMirrorLoadRules, isFollowed: Bool)] = [
            (.original, true),
            (.mirror { _, _ in true }, false)
        ]

        for testCase in cases {
            let task = loader.load(URLRequest(url: url), rules: testCase.rules) { _ in }
            let sessionTask = try XCTUnwrap(task as? URLSessionTask)
            var followedRequest: URLRequest?

            loader.urlSession(.shared, task: sessionTask, willPerformHTTPRedirection: response, newRequest: newRequest) {
                followedRequest = $0
            }

            XCTAssertEqual(followedRequest?.url, testCase.isFollowed ? newRequest.url : nil)

            task.cancel()
        }
    }

    func testAnswerIsFromLocalCacheOnlyWhenServerWasNotAsked() {
        XCTAssertTrue(ConfigMirrorLoader.isServedFromLocalCache([.localCache]))

        // a cached answer the server has confirmed
        XCTAssertFalse(ConfigMirrorLoader.isServedFromLocalCache([.localCache, .networkLoad]))
        XCTAssertFalse(ConfigMirrorLoader.isServedFromLocalCache([.networkLoad]))
        XCTAssertFalse(ConfigMirrorLoader.isServedFromLocalCache([.unknown]))
        XCTAssertFalse(ConfigMirrorLoader.isServedFromLocalCache([]))
    }
}

private extension ConfigMirrorLoaderTests {
    func load(_ name: String) -> (task: ConfigMirrorLoadTaskProtocol, completion: XCTestExpectation) {
        let completion = expectation(description: "\(name) completed")
        let request = URLRequest(url: URL(string: "https://loader.novatest/\(name)")!)

        let task = loader.load(request, rules: .original) { [weak self] event in
            let description: String

            switch event {
            case let .response(response): description = "response \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            case let .data(data): description = "data \(String(data: data, encoding: .utf8) ?? "")"
            case .servedFromLocalCache: description = "served from local cache"
            case let .completed(error): description = "completed \((error as NSError?)?.code ?? 0)"
            }

            self?.mutex.lock()
            self?.events[name, default: []].append(description)
            self?.mutex.unlock()

            if case .completed = event {
                completion.fulfill()
            }
        }

        return (task, completion)
    }

    func recordedEvents(of name: String) -> [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return events[name] ?? []
    }
}
