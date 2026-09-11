import XCTest
import Operation_iOS
@testable import novawallet

private final class GlobalConfigStubURLProtocol: URLProtocol {
    static let scheme = "novaglobalconfigstub"
    static var payload = Data()

    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == scheme }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class GlobalConfigProviderTests: XCTestCase {
    private let configUrl = URL(string: "\(GlobalConfigStubURLProtocol.scheme)://global/config.json")!

    override func setUp() {
        super.setUp()
        GlobalConfigStubURLProtocol.payload = Data()
        XCTAssertTrue(URLProtocol.registerClass(GlobalConfigStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(GlobalConfigStubURLProtocol.self)
        super.tearDown()
    }

    func testOnlyAFreshFetchObservesAChangedPayload() throws {
        GlobalConfigStubURLProtocol.payload = makePayload(analyticsEnabled: true)

        let provider = GlobalConfigProvider(configUrl: configUrl)

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, true)

        GlobalConfigStubURLProtocol.payload = makePayload(analyticsEnabled: false)

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).analytics?.enabled, true)
        XCTAssertEqual(try fetch(provider.createFreshConfigWrapper()).analytics?.enabled, false)
    }

    private func makePayload(analyticsEnabled: Bool) -> Data {
        Data(#"{"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","analytics":{"enabled":\#(analyticsEnabled)}}"#.utf8)
    }

    private func fetch(_ wrapper: CompoundOperationWrapper<GlobalConfig>) throws -> GlobalConfig {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
