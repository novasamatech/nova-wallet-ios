import XCTest
@testable import novawallet

final class StakingCompetitorsRemoteProviderTests: XCTestCase {
    // MARK: - Test infrastructure

    /// URLProtocol stub that returns canned data/errors for any request.
    final class StubURLProtocol: URLProtocol {
        static var stubbedData: Data?
        static var stubbedError: Error?
        static var stubbedStatusCode: Int = 200

        override class func canInit(with _: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            if let error = Self.stubbedError {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: Self.stubbedStatusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = Self.stubbedData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.stubbedData = nil
        StubURLProtocol.stubbedError = nil
        StubURLProtocol.stubbedStatusCode = 200
    }

    private func makeProvider() -> StakingCompetitorsRemoteProvider {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return StakingCompetitorsRemoteProvider(
            url: URL(string: "https://stub.test/staking_competitors.json")!,
            session: session
        )
    }

    // MARK: - Tests

    func test_isStakingCompetitor_emptyCache_returnsFalse() {
        let provider = makeProvider()
        XCTAssertFalse(provider.isStakingCompetitor(url: URL(string: "https://staking.polkadot.cloud/")!))
    }

    func test_sync_successfulFetch_populatesCache() async {
        StubURLProtocol.stubbedData = #"""
        { "version": 1, "domains": ["staking.polkadot.cloud"] }
        """#.data(using: .utf8)

        let provider = makeProvider()
        await provider.sync()

        XCTAssertTrue(provider.isStakingCompetitor(url: URL(string: "https://staking.polkadot.cloud/")!))
        XCTAssertTrue(provider.isStakingCompetitor(url: URL(string: "https://sub.staking.polkadot.cloud/")!), "subdomain match")
        XCTAssertFalse(provider.isStakingCompetitor(url: URL(string: "https://app.hydration.net/")!))
    }

    func test_sync_networkError_leavesCacheEmpty_failOpen() async {
        StubURLProtocol.stubbedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        let provider = makeProvider()
        await provider.sync()

        XCTAssertFalse(
            provider.isStakingCompetitor(url: URL(string: "https://staking.polkadot.cloud/")!),
            "Fail-open: network failure must NOT block navigation by returning true"
        )
    }

    func test_sync_malformedJSON_leavesCacheEmpty_failOpen() async {
        StubURLProtocol.stubbedData = "not json at all".data(using: .utf8)

        let provider = makeProvider()
        await provider.sync()

        XCTAssertFalse(provider.isStakingCompetitor(url: URL(string: "https://staking.polkadot.cloud/")!))
    }
}
