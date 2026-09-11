import XCTest
@testable import NovaAnalytics

final class AnalyticsContentValueTests: XCTestCase {
    private let freeText = "Alice's wallet, do not share"
    private let overlong = String(repeating: "a", count: 300)

    private let registrySymbols = [
        "DOT", "vDOT", "xcDOT", "USDT", "USDC.e", "BTC-b", "1INCH",
        "LP DOT-iBTC", "LP INTR-USDT", "LP KSM-KINT", "LP KSM-kBTC", "LP iBTC-USDT", "LP kBTC-USDT",
        "RMRK (old)", "xcRMRK (old)"
    ]

    private let registryNamesWithParenthesisedSuffixes = [
        "3DPass (PAUSED)", "Aleph Zero EVM (PAUSED)", "Amplitude (PAUSED)", "Argochain (PAUSED)",
        "Crab (PAUSED)", "Crust Polkadot Parachain (PAUSED)", "Crust Shadow (PAUSED)", "DAO IPCI (PAUSED)",
        "Dock (PAUSED)", "Edgeware (PAUSED)", "Exosama (PAUSED)", "Hashed Network (PAUSED)",
        "Integritee Parachain (PAUSED)", "Interlay (PAUSED)", "KILT (PAUSED)", "Kabocha (PAUSED)",
        "Kintsugi (PAUSED)", "Laos (PAUSED)", "Mangata X (PAUSED)", "Moonbeam (PAUSED)", "Moonriver (PAUSED)",
        "Myriad (PAUSED)", "Nodle Parachain (PAUSED)", "Phala (PAUSED)", "Picasso (PAUSED)", "QUARTZ (PAUSED)",
        "Subsocial (PAUSED)", "Tangle (PAUSED)", "Tanssi (PAUSED)", "Westend (TESTNET)", "Xode (PAUSED)",
        "Zeitgeist (PAUSED)", "krest (PAUSED)"
    ]

    private func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }

    func testAssetSymbolAcceptsRegistrySymbolsWithoutChangingCase() {
        for symbol in registrySymbols {
            XCTAssertEqual(AnalyticsContentValue.assetSymbol(symbol)?.stringValue, symbol)
        }
    }

    func testAssetSymbolRejectsFreeText() {
        let values = [
            "DOT  USD", " DOT", "DOT ", "DOT\tUSD", "DÖT", "DOT_2", "DOT:1", "", " ", "\u{212A}SM", freeText, overlong
        ]

        for value in values {
            XCTAssertNil(AnalyticsContentValue.assetSymbol(value), value)
        }
    }

    func testNetworkNameAcceptsRegistryNamesWithParenthesisedSuffixes() {
        for name in registryNamesWithParenthesisedSuffixes {
            XCTAssertEqual(AnalyticsContentValue.networkName(name)?.stringValue, name)
        }
    }

    func testDappHostKeepsOnlyTheLowercasedHost() throws {
        XCTAssertEqual(
            AnalyticsContentValue.dappHost(try url("https://app.hydration.net/trade"))?.stringValue,
            "app.hydration.net"
        )
        XCTAssertEqual(
            AnalyticsContentValue.dappHost(try url("HTTPS://APP.Hydration.NET/Trade?account=alice#top"))?.stringValue,
            "app.hydration.net"
        )
        XCTAssertEqual(
            AnalyticsContentValue.dappHost(try url("https://app.example.org:8443/"))?.stringValue,
            "app.example.org"
        )
    }

    func testCaip2ChainAcceptsChainIdentifiers() {
        let values = [
            "polkadot:91b171bb158e2d3848fa23a9f1c25182",
            "polkadot:b0a8d493285c2df73290dfb7e61f870f",
            "eip155:1",
            "eip155:1284",
            "bip122:000000000019d6689c085ae165831e93",
            "cosmos:cosmoshub-3"
        ]

        for value in values {
            XCTAssertEqual(AnalyticsContentValue.caip2Chain(value)?.stringValue, value)
        }
    }
}
