import XCTest
@testable import NovaAnalytics

final class AnalyticsPropertyValueTests: XCTestCase {
    private func encodeToString(_ props: [String: AnalyticsPropertyValue]) throws -> String {
        String(data: try AnalyticsCoding.encoder.encode(props), encoding: .utf8)!
    }

    private func decodeWire(_ data: Data) throws -> [String: AnalyticsWireValue] {
        try AnalyticsCoding.decoder.decode([String: AnalyticsWireValue].self, from: data)
    }

    func testEachCaseEncodesToItsJSONPrimitive() throws {
        let props: [String: AnalyticsPropertyValue] = [
            "a_bool": .bool(true),
            "c_enum": .enumerated("native_token"),
            "d_content": .content(.assetSymbol("DOT")!)
        ]

        XCTAssertEqual(
            try encodeToString(props),
            #"{"a_bool":true,"c_enum":"native_token","d_content":"DOT"}"#
        )
    }

    func testStoredPayloadDecodesIntoWireValues() throws {
        let original: [String: AnalyticsPropertyValue] = [
            "a": .bool(false),
            "c": .enumerated("setup"),
            "d": .content(.dappHost(URL(string: "https://app.example.org/trade")!)!)
        ]

        let decoded = try decodeWire(try AnalyticsCoding.encoder.encode(original))

        XCTAssertEqual(
            decoded,
            ["a": .bool(false), "c": .string("setup"), "d": .string("app.example.org")]
        )
    }

    func testStoredPayloadIsByteStableThroughTheWireType() throws {
        let original: [String: AnalyticsPropertyValue] = [
            "a": .bool(false),
            "c": .enumerated("setup"),
            "d": .content(.dappHost(URL(string: "https://app.example.org/trade")!)!)
        ]

        let firstPass = try AnalyticsCoding.encoder.encode(original)
        let secondPass = try AnalyticsCoding.encoder.encode(try decodeWire(firstPass))

        XCTAssertEqual(firstPass, secondPass)
    }

    func testWireDecoderRejectsAnythingButPrimitives() {
        XCTAssertThrowsError(try decodeWire(Data(#"{"a":{"b":1}}"#.utf8)))
        XCTAssertThrowsError(try decodeWire(Data(#"{"a":[1]}"#.utf8)))
        XCTAssertThrowsError(try decodeWire(Data(#"{"a":null}"#.utf8)))
        XCTAssertThrowsError(try decodeWire(Data(#"{"a":1.5}"#.utf8)))
    }

    func testNilPropertiesAreOmittedNotNulled() throws {
        let event = AnalyticsEvent(
            name: .sendCompleted,
            properties: [
                .asset: AnalyticsContentValue.assetSymbol("DOT"),
                .destinationNetwork: nil
            ]
        )

        XCTAssertEqual(Set(event.properties.keys), [.asset])
        XCTAssertNil(event.properties[.destinationNetwork])
    }

    func testRejectedContentIsOmittedFromTheEvent() {
        let event = AnalyticsEvent(
            name: .sendCompleted,
            properties: [.destinationNetwork: AnalyticsContentValue.networkName("Bob's  network!")]
        )

        XCTAssertTrue(event.properties.isEmpty)
    }

    func testRawRepresentableEnumsConvertForFree() {
        XCTAssertEqual(AssetCategory.stablecoin.analyticsValue, .enumerated("stablecoin"))
    }

    func testTimestampFormatCarriesMillisecondsInUTC() {
        let formatted = ISO8601MillisFormatter.string(from: Date(timeIntervalSince1970: 1_772_445_600.123))
        XCTAssertTrue(formatted.hasSuffix(".123Z"), formatted)
        XCTAssertEqual(formatted.count, 24, formatted)
    }

    func testEventNameAndPropertyKeyRawValuesAreWireNames() {
        XCTAssertEqual(AnalyticsEventName.appOpened.rawValue, "app_opened")
        XCTAssertEqual(AnalyticsEventName.signFailed.rawValue, "sign_failed")
        XCTAssertEqual(AnalyticsPropertyKey.isFirstLaunch.rawValue, "is_first_launch")
        XCTAssertEqual(AnalyticsPropertyKey.destinationNetwork.rawValue, "destination_network")
        XCTAssertEqual(AnalyticsPropertyKey.nftCountBucket.rawValue, "nft_count_bucket")
        XCTAssertEqual(AnalyticsEventName.allCases.count, 42)
        XCTAssertEqual(AnalyticsPropertyKey.allCases.count, 32)
    }
}
