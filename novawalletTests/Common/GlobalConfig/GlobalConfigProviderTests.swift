import XCTest
import Operation_iOS
@testable import novawallet

private final class GlobalConfigStubURLProtocol: URLProtocol {
    static let scheme = "novaglobalconfigstub"

    private static let mutex = NSLock()
    private static var payload = Data()
    private static var requestCount = 0

    static var observedRequestCount: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return requestCount
    }

    static func setPayload(_ data: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        payload = data
    }

    static func reset() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        payload = Data()
        requestCount = 0
    }

    static func recordRequest() -> Data {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        requestCount += 1

        return payload
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == scheme
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let payload = Self.recordRequest()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// `createConfigWrapper()` memoises for the whole process, which is what the analytics kill
/// switch cannot live with: without a cache-bypassing entry point a switch thrown mid-process
/// is invisible until the next launch.
final class GlobalConfigProviderTests: XCTestCase {
    private let configUrl = URL(string: "\(GlobalConfigStubURLProtocol.scheme)://global/config.json")!

    override func setUp() {
        super.setUp()

        GlobalConfigStubURLProtocol.reset()

        XCTAssertTrue(URLProtocol.registerClass(GlobalConfigStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(GlobalConfigStubURLProtocol.self)
        GlobalConfigStubURLProtocol.reset()

        super.tearDown()
    }

    func testTheCachedWrapperStopsFetchingAfterTheFirstSuccess() throws {
        let provider = makeProvider(analyticsEnabled: true)

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, true)

        GlobalConfigStubURLProtocol.setPayload(makePayload(analyticsEnabled: false))

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, true)
        XCTAssertEqual(GlobalConfigStubURLProtocol.observedRequestCount, 1)
    }

    func testASecondFreshFetchObservesAChangedPayload() throws {
        let provider = makeProvider(analyticsEnabled: true)

        XCTAssertEqual(try fetch(provider.createFreshConfigWrapper()).analytics?.enabled, true)

        GlobalConfigStubURLProtocol.setPayload(makePayload(analyticsEnabled: false))

        XCTAssertEqual(try fetch(provider.createFreshConfigWrapper()).analytics?.enabled, false)
        XCTAssertEqual(GlobalConfigStubURLProtocol.observedRequestCount, 2)
    }

    func testAFreshFetchRefreshesTheValueTheCachedWrapperReturns() throws {
        let provider = makeProvider(analyticsEnabled: true)

        _ = try fetch(provider.createConfigWrapper())

        GlobalConfigStubURLProtocol.setPayload(makePayload(analyticsEnabled: false))

        _ = try fetch(provider.createFreshConfigWrapper())

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, false)
        XCTAssertEqual(GlobalConfigStubURLProtocol.observedRequestCount, 2)
    }

    func testAFailedFreshFetchLeavesTheCachedConfigInPlace() throws {
        let provider = makeProvider(analyticsEnabled: true)

        _ = try fetch(provider.createConfigWrapper())

        GlobalConfigStubURLProtocol.setPayload(Data("not a config".utf8))

        XCTAssertThrowsError(try fetch(provider.createFreshConfigWrapper()))
        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, true)
    }
}

// MARK: - Private

private extension GlobalConfigProviderTests {
    func makeProvider(analyticsEnabled: Bool) -> GlobalConfigProvider {
        GlobalConfigStubURLProtocol.setPayload(makePayload(analyticsEnabled: analyticsEnabled))

        return GlobalConfigProvider(configUrl: configUrl)
    }

    func makePayload(analyticsEnabled: Bool) -> Data {
        Data("""
        {
          "multiStakingApiUrl": "https://a.example",
          "multisigsApiUrl": "https://b.example",
          "proxyApiUrl": "https://c.example",
          "analytics": { "enabled": \(analyticsEnabled) }
        }
        """.utf8)
    }

    func fetch(_ wrapper: CompoundOperationWrapper<GlobalConfig>) throws -> GlobalConfig {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
