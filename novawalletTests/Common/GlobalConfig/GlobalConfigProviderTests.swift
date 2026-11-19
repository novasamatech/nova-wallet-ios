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
        GlobalConfigStubURLProtocol.payload = makePayload(infraUrl: "https://first.example")

        let provider = GlobalConfigProvider(configUrl: configUrl)

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).infraUrl.absoluteString, "https://first.example")

        GlobalConfigStubURLProtocol.payload = makePayload(infraUrl: "https://second.example")

        XCTAssertEqual(try fetch(provider.createConfigWrapper()).infraUrl.absoluteString, "https://first.example")
        XCTAssertEqual(
            try fetch(provider.createFreshConfigWrapper()).infraUrl.absoluteString,
            "https://second.example"
        )
    }

    func testDecodesTheChangeNowTaoUrlOnlyWhenPresent() throws {
        let changeNowTaoUrl = "https://changenow.io/exchange?from=assethub&to=tao&link_id=59409968ba3831"

        GlobalConfigStubURLProtocol.payload = makePayload(
            infraUrl: "https://first.example",
            changeNowTaoUrl: changeNowTaoUrl
        )

        let configWithUrl = try fetch(GlobalConfigProvider(configUrl: configUrl).createConfigWrapper())

        XCTAssertEqual(configWithUrl.changeNowTaoUrl?.absoluteString, changeNowTaoUrl)

        GlobalConfigStubURLProtocol.payload = makePayload(infraUrl: "https://second.example")

        let configWithoutUrl = try fetch(GlobalConfigProvider(configUrl: configUrl).createConfigWrapper())

        XCTAssertNil(configWithoutUrl.changeNowTaoUrl)
        XCTAssertEqual(configWithoutUrl.infraUrl.absoluteString, "https://second.example")
    }

    func testDecodesThePublishedDefaultSwapPair() throws {
        let assetHubId = "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"

        GlobalConfigStubURLProtocol.payload = makePayload(
            infraUrl: "https://first.example",
            defaultSwapPair: #"{"assetIn":{"chainId":"\#(assetHubId)","assetId":0},"assetOut":{"chainId":"\#(assetHubId)","assetId":2}}"#
        )

        let config = try fetch(GlobalConfigProvider(configUrl: configUrl).createConfigWrapper())

        XCTAssertEqual(
            config.defaultSwapPair,
            SwapAssetPairId(
                pay: ChainAssetId(chainId: assetHubId, assetId: 0),
                receive: ChainAssetId(chainId: assetHubId, assetId: 2)
            )
        )
    }

    func testDropsAMalformedDefaultSwapPairButKeepsTheEndpoints() throws {
        GlobalConfigStubURLProtocol.payload = makePayload(
            infraUrl: "https://first.example",
            defaultSwapPair: #"{"assetIn":{"chainId":"0x"}}"#
        )

        let config = try fetch(GlobalConfigProvider(configUrl: configUrl).createConfigWrapper())

        XCTAssertNil(config.defaultSwapPair)
        XCTAssertEqual(config.infraUrl.absoluteString, "https://first.example")
    }

    private func makePayload(
        infraUrl: String,
        changeNowTaoUrl: String? = nil,
        defaultSwapPair: String? = nil
    ) -> Data {
        let changeNowField = changeNowTaoUrl.map { #","changeNowTaoUrl":"\#($0)""# } ?? ""
        let swapPairField = defaultSwapPair.map { #","defaultSwapPair":\#($0)"# } ?? ""

        return Data(#"{"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","infraUrl":"\#(infraUrl)"\#(changeNowField)\#(swapPairField)}"#.utf8)
    }

    private func fetch(_ wrapper: CompoundOperationWrapper<GlobalConfig>) throws -> GlobalConfig {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
