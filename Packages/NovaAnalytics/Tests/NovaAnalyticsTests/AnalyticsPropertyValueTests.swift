import XCTest
@testable import NovaAnalytics

final class AnalyticsPropertyValueTests: XCTestCase {
    func testEncodesJSONValues() throws {
        let props: [String: AnalyticsPropertyValue] = [
            "enabled": .bool(true),
            "category": .enumerated("native_token"),
            "asset": .content(try XCTUnwrap(.assetSymbol("DOT")))
        ]

        XCTAssertEqual(
            String(data: try AnalyticsCoding.encoder.encode(props), encoding: .utf8),
            #"{"asset":"DOT","category":"native_token","enabled":true}"#
        )
    }

    func testOmitsNilProperties() {
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

    func testTimestampIncludesUTCMilliseconds() {
        let formatted = ISO8601MillisFormatter.string(from: Date(timeIntervalSince1970: 1_772_445_600.123))

        XCTAssertTrue(formatted.hasSuffix(".123Z"), formatted)
        XCTAssertEqual(formatted.count, 24, formatted)
    }
}
