import XCTest
@testable import NovaAnalytics

final class AnalyticsContentValueTests: XCTestCase {
    private let freeText = "Alice's wallet, do not share"
    private let overlong = String(repeating: "a", count: 300)

    private func url(_ string: String) throws -> URL {
        try XCTUnwrap(URL(string: string))
    }

    private func identifierFactories() -> [(String) -> AnalyticsContentValue?] {
        [
            AnalyticsContentValue.providerId,
            AnalyticsContentValue.bannerId,
            AnalyticsContentValue.signingMethod
        ]
    }

    func testAssetSymbolAcceptsRealSymbolsWithoutChangingCase() {
        for symbol in ["DOT", "vDOT", "xcDOT", "USDT", "USDC.e", "BTC-b", "1INCH"] {
            XCTAssertEqual(AnalyticsContentValue.assetSymbol(symbol)?.stringValue, symbol)
        }
    }

    func testAssetSymbolAcceptsUpToSixteenCharacters() {
        XCTAssertNotNil(AnalyticsContentValue.assetSymbol(String(repeating: "A", count: 16)))
        XCTAssertNil(AnalyticsContentValue.assetSymbol(String(repeating: "A", count: 17)))
    }

    func testAssetSymbolRejectsFreeText() {
        for value in ["DOT USD", "DÖT", "DOT_2", "DOT:1", "", " DOT", "\u{212A}SM", freeText, overlong] {
            XCTAssertNil(AnalyticsContentValue.assetSymbol(value), value)
        }
    }

    func testNetworkNameAcceptsSingleSpacedTokens() {
        for name in ["Polkadot", "Polkadot Asset Hub", "Hydration", "Bifrost-Polkadot", "Kusama.v2", "Moonbeam 2"] {
            XCTAssertEqual(AnalyticsContentValue.networkName(name)?.stringValue, name)
        }
    }

    func testNetworkNameAcceptsUpToThirtyTwoCharacters() {
        XCTAssertNotNil(AnalyticsContentValue.networkName(String(repeating: "N", count: 32)))
        XCTAssertNil(AnalyticsContentValue.networkName(String(repeating: "N", count: 33)))
    }

    func testNetworkNameRejectsFreeText() {
        let values = [
            "Polkadot  Asset Hub", " Polkadot", "Polkadot ", "Polkadot\tHub", "Polkadot\nHub",
            "Полкадот", "Bob's Network!", "Net_work", "", " ", freeText, overlong
        ]

        for value in values {
            XCTAssertNil(AnalyticsContentValue.networkName(value), value)
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

    func testDappHostAcceptsUpToSixtyFourCharacters() throws {
        let host = String(repeating: "a", count: 60) + ".net"

        XCTAssertEqual(AnalyticsContentValue.dappHost(try url("https://\(host)/"))?.stringValue, host)
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("https://a\(host)/")))
    }

    func testDappHostRejectsUserinfo() throws {
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("https://alice:hunter2@app.example.org/")))
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("https://alice@app.example.org/")))
    }

    func testDappHostRejectsHostsOutsideTheHostnameGrammar() throws {
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("https://[::1]/")))
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("https://b%C3%BCcher.example/")))
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("file:///tmp/wallet.json")))
        XCTAssertNil(AnalyticsContentValue.dappHost(try url("mailto:alice@example.org")))
    }

    func testProviderIdAcceptsIdentifiers() {
        for value in ["mercuryo", "transak", "banxa-v2", "moonpay.widget", "on_ramper"] {
            XCTAssertEqual(AnalyticsContentValue.providerId(value)?.stringValue, value)
        }
    }

    func testBannerIdAcceptsIdentifiers() {
        for value in ["ahm-2026", "nova_card", "ahm.polkadot.2026"] {
            XCTAssertEqual(AnalyticsContentValue.bannerId(value)?.stringValue, value)
        }
    }

    func testSigningMethodAcceptsMethodNames() {
        for value in ["polkadot_signPayload", "eth_sendTransaction", "personal_sign", "wallet_switchEthereumChain"] {
            XCTAssertEqual(AnalyticsContentValue.signingMethod(value)?.stringValue, value)
        }
    }

    func testIdentifierFactoriesAcceptUpToSixtyFourCharacters() {
        for factory in identifierFactories() {
            XCTAssertNotNil(factory(String(repeating: "x", count: 64)))
            XCTAssertNil(factory(String(repeating: "x", count: 65)))
        }
    }

    func testIdentifierFactoriesRejectFreeText() {
        for factory in identifierFactories() {
            for value in ["mercuryo widget", "polkadot:sign", "eth/send", "", "Ünicode", freeText, overlong] {
                XCTAssertNil(factory(value), value)
            }
        }
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

    func testCaip2ChainRejectsAnythingOutsideTheGrammar() {
        let values = [
            "polkadot:91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            "Polkadot:91b171bb158e2d3848fa23a9f1c25182",
            "po:1", "polkadot", "polkadot:", ":1", "polkadot:a:b", "polkadot:abc def", "eip155:1 ",
            "toolongnamespace:1", "", freeText, overlong
        ]

        for value in values {
            XCTAssertNil(AnalyticsContentValue.caip2Chain(value), value)
        }
    }

    func testEqualityIsByKindAndValue() {
        XCTAssertEqual(AnalyticsContentValue.assetSymbol("DOT"), AnalyticsContentValue.assetSymbol("DOT"))
        XCTAssertNotEqual(AnalyticsContentValue.assetSymbol("DOT"), AnalyticsContentValue.bannerId("DOT"))
        XCTAssertEqual(AnalyticsContentValue.assetSymbol("DOT")?.kind, .assetSymbol)
    }

    func testContentConvertsToAContentPropertyValue() throws {
        let value = try XCTUnwrap(AnalyticsContentValue.assetSymbol("DOT"))

        XCTAssertEqual(value.analyticsValue, .content(value))
    }

    func testEveryFactoryGrammarSitsInsideTheBoundaryGrammar() {
        let boundary = AnalyticsWirePayloadPolicy.grammar

        for kind in AnalyticsContentValue.Kind.allCases {
            let grammar = kind.grammar

            for code in 0 ..< 128 {
                let scalar = Unicode.Scalar(UInt8(code))

                XCTAssertTrue(
                    !grammar.alphabet.contains(scalar) || boundary.alphabet.contains(scalar),
                    "\(kind) admits U+\(String(code, radix: 16)) which the boundary refuses"
                )
            }

            XCTAssertGreaterThanOrEqual(grammar.lengths.lowerBound, boundary.lengths.lowerBound, "\(kind)")
            XCTAssertLessThanOrEqual(grammar.lengths.upperBound, boundary.lengths.upperBound, "\(kind)")
        }
    }

    func testEveryAcceptedExamplePassesTheBoundaryGrammar() throws {
        let accepted: [AnalyticsContentValue?] = [
            .assetSymbol("xcDOT"),
            .networkName("Polkadot Asset Hub"),
            .dappHost(try url("https://app.hydration.net/trade")),
            .providerId("mercuryo"),
            .bannerId("ahm-2026"),
            .signingMethod("polkadot_signPayload"),
            .caip2Chain("polkadot:91b171bb158e2d3848fa23a9f1c25182")
        ]

        for value in accepted {
            let value = try XCTUnwrap(value)

            XCTAssertTrue(AnalyticsWirePayloadPolicy.grammar.accepts(value.stringValue), value.stringValue)
        }
    }
}
