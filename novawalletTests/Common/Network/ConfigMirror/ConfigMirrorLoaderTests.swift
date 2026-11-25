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

    func testKeepsOutOfHttpCacheAnswersToRequestsThatIgnoreIt() throws {
        let url = try XCTUnwrap(URL(string: "https://loader.novatest/file.json"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let proposedResponse = CachedURLResponse(response: response, data: Data("{}".utf8))

        let policies: [(policy: URLRequest.CachePolicy, isCached: Bool)] = [
            (.useProtocolCachePolicy, true),
            (.returnCacheDataElseLoad, true),
            (.reloadIgnoringLocalCacheData, false),
            (.reloadIgnoringLocalAndRemoteCacheData, false)
        ]

        for (policy, isCached) in policies {
            let task = URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: policy))
            var cachedResponse: CachedURLResponse?

            loader.urlSession(.shared, dataTask: task, willCacheResponse: proposedResponse) { cachedResponse = $0 }

            XCTAssertEqual(cachedResponse != nil, isCached, "\(policy.rawValue)")

            task.cancel()
        }
    }
}

private extension ConfigMirrorLoaderTests {
    func load(_ name: String) -> (task: ConfigMirrorLoadTaskProtocol, completion: XCTestExpectation) {
        let completion = expectation(description: "\(name) completed")
        let request = URLRequest(url: URL(string: "https://loader.novatest/\(name)")!)

        let task = loader.load(request) { [weak self] event in
            let description: String

            switch event {
            case let .response(response): description = "response \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            case let .data(data): description = "data \(String(data: data, encoding: .utf8) ?? "")"
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
