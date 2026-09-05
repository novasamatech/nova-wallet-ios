import XCTest
@testable import NovaAnalytics

final class AnalyticsPropertyValueTests: XCTestCase {
    private func encodeToString(_ props: [String: AnalyticsPropertyValue]) throws -> String {
        String(data: try AnalyticsCoding.encoder.encode(props), encoding: .utf8)!
    }

    func testEachCaseEncodesToItsJSONPrimitive() throws {
        let props: [String: AnalyticsPropertyValue] = [
            "a_bool": .bool(true),
            "b_int": .int(3),
            "c_enum": .enumerated("native_token"),
            "d_content": .content(.assetSymbol("DOT"))
        ]

        XCTAssertEqual(
            try encodeToString(props),
            #"{"a_bool":true,"b_int":3,"c_enum":"native_token","d_content":"DOT"}"#
        )
    }

    func testIntEncodesAsNumberNotString() throws {
        XCTAssertEqual(try encodeToString(["nft_count": .int(3)]), #"{"nft_count":3}"#)
    }

    func testDecodeIsLossyButWireStable() throws {
        let original: [String: AnalyticsPropertyValue] = [
            "a": .bool(false),
            "b": .int(0),
            "c": .enumerated("setup"),
            "d": .content(.dappHost("app.example.org"))
        ]

        let firstPass = try AnalyticsCoding.encoder.encode(original)
        let decoded = try AnalyticsCoding.decoder.decode([String: AnalyticsPropertyValue].self, from: firstPass)
        let secondPass = try AnalyticsCoding.encoder.encode(decoded)

        XCTAssertEqual(firstPass, secondPass)
        XCTAssertEqual(decoded["c"], .content(.raw("setup")))
        XCTAssertEqual(decoded["a"], .bool(false))
        XCTAssertEqual(decoded["b"], .int(0))
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
        XCTAssertEqual(AnalyticsEventName.allCases.count, 42)
        XCTAssertEqual(AnalyticsPropertyKey.allCases.count, 32)
    }
}
