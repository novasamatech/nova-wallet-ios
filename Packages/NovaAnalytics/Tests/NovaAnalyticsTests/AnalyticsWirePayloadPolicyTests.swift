import XCTest
@testable import NovaAnalytics

final class AnalyticsWirePayloadPolicyTests: XCTestCase {
    private func makeRow(payload: String) -> AnalyticsPendingEvent {
        AnalyticsPendingEvent(
            identifier: "row-1",
            sequence: 1,
            name: "nova_card_opened",
            timestamp: Date(timeIntervalSince1970: 1_788_343_200.123),
            payload: Data(payload.utf8),
            consentEpoch: 1
        )
    }

    func testWellFormedRowBecomesTheWireEvent() throws {
        let row = makeRow(payload: #"{"asset":"DOT","is_cross_chain":false}"#)

        XCTAssertEqual(
            try AnalyticsWirePayloadPolicy.vet(row),
            AnalyticsEventRemote(
                id: "row-1",
                name: "nova_card_opened",
                timestamp: "2026-09-02T10:00:00.123Z",
                props: ["asset": .string("DOT"), "is_cross_chain": .bool(false)]
            )
        )
    }

    func testFreeTextValueMarksTheRowAsPoison() {
        let row = makeRow(payload: #"{"asset":"my savings wallet!"}"#)

        XCTAssertThrowsError(try AnalyticsWirePayloadPolicy.vet(row)) { error in
            XCTAssertTrue(error is AnalyticsWirePayloadPolicyError, "\(error)")
        }
    }
}
