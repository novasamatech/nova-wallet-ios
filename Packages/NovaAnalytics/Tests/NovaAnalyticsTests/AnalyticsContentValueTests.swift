import XCTest
@testable import NovaAnalytics

final class AnalyticsContentValueTests: XCTestCase {
    func testAssetSymbolPreservesCase() {
        for symbol in ["DOT", "vDOT", "LP DOT-iBTC", "RMRK (old)"] {
            XCTAssertEqual(AnalyticsContentValue.assetSymbol(symbol)?.stringValue, symbol)
        }
    }

    func testAssetSymbolRejectsInvalidContent() {
        XCTAssertNil(AnalyticsContentValue.assetSymbol("Alice's wallet, do not share"))
        XCTAssertNil(AnalyticsContentValue.assetSymbol(""))
        XCTAssertNil(AnalyticsContentValue.assetSymbol(String(repeating: "a", count: 300)))
    }

    func testNetworkNameAcceptsRegistrySuffix() {
        let name = "Westend (TESTNET)"

        XCTAssertEqual(AnalyticsContentValue.networkName(name)?.stringValue, name)
    }

    func testDappHostStripsPathAndQuery() throws {
        let url = try XCTUnwrap(URL(string: "https://APP.Hydration.NET:8443/trade?account=alice#top"))

        XCTAssertEqual(AnalyticsContentValue.dappHost(url)?.stringValue, "app.hydration.net")
    }

    func testCaip2ChainAcceptsIdentifiers() {
        for chain in ["eip155:1", "polkadot:91b171bb158e2d3848fa23a9f1c25182"] {
            XCTAssertEqual(AnalyticsContentValue.caip2Chain(chain)?.stringValue, chain)
        }
    }
}
