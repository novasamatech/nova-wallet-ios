import XCTest
@testable import NovaAnalytics

final class AnalyticsPropertyValueTests: XCTestCase {
    func testEachCaseEncodesToItsJSONPrimitive() throws {
        let props: [String: AnalyticsPropertyValue] = [
            "a_bool": .bool(true),
            "c_enum": .enumerated("native_token"),
            "d_content": .content(.assetSymbol("DOT")!)
        ]

        XCTAssertEqual(
            String(data: try AnalyticsCoding.encoder.encode(props), encoding: .utf8),
            #"{"a_bool":true,"c_enum":"native_token","d_content":"DOT"}"#
        )
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

    func testTimestampFormatCarriesMillisecondsInUTC() {
        let formatted = ISO8601MillisFormatter.string(from: Date(timeIntervalSince1970: 1_772_445_600.123))

        XCTAssertTrue(formatted.hasSuffix(".123Z"), formatted)
        XCTAssertEqual(formatted.count, 24, formatted)
    }
}
