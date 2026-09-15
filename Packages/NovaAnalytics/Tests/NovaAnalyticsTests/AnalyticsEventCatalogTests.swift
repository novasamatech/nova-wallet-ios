import XCTest
@testable import NovaAnalytics

final class AnalyticsEventCatalogTests: XCTestCase {
    func testSendCompletedProperties() throws {
        let event = AnalyticsEvent.sendCompleted(
            asset: try XCTUnwrap(AnalyticsContentValue.assetSymbol("DOT")),
            network: try XCTUnwrap(AnalyticsContentValue.networkName("Polkadot")),
            destinationNetwork: nil,
            amount: 10,
            rate: 5
        )

        let data = try AnalyticsCoding.encoder.encode(event.wireProperties)

        XCTAssertEqual(event.name.rawValue, "send_completed")
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            #"{"amount_bucket":"10_to_100","asset":"DOT","network":"Polkadot"}"#
        )
    }
}
