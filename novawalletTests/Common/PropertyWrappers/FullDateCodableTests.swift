import XCTest
@testable import novawallet

final class FullDateCodableTests: XCTestCase {
    fileprivate struct Payload: Codable, Equatable {
        @FullDateCodable var day: Date
    }

    func testDecodesFullDateAsUTCMidnight() throws {
        let payload = try decode(#"{"day": "2026-08-04"}"#)

        XCTAssertEqual(payload.day, date(year: 2026, month: 8, day: 4))
    }

    func testKeepsTheDayRegardlessOfTheCurrentTimeZone() throws {
        let payload = try decode(#"{"day": "2026-01-01"}"#)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(calendar.component(.day, from: payload.day), 1)
        XCTAssertEqual(calendar.component(.month, from: payload.day), 1)
        XCTAssertEqual(calendar.component(.year, from: payload.day), 2026)
    }

    func testRoundTripsThroughEncoding() throws {
        let payload = try decode(#"{"day": "2026-03-04"}"#)

        let encoded = try JSONEncoder().encode(payload)
        let restored = try JSONDecoder().decode(Payload.self, from: encoded)

        XCTAssertEqual(restored, payload)
    }

    /// `withFullDate` on its own accepts the first three: the round trip check in the wrapper is
    /// what rejects them, so a config that misses the exact format invalidates the whole payload.
    func testRejectsValuesThatAreNotACanonicalFullDate() {
        let values = [
            "2026-8-4",
            "2026/08/04",
            "2026-08-04T00:00:00Z",
            "2026-13-45",
            "20260804",
            "4 March 2026",
            ""
        ]

        for value in values {
            XCTAssertThrowsError(
                try decode(#"{"day": "\#(value)"}"#),
                "expected \(value) to be rejected"
            )
        }
    }
}

private extension FullDateCodableTests {
    func decode(_ json: String) throws -> Payload {
        try JSONDecoder().decode(Payload.self, from: Data(json.utf8))
    }

    func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(secondsFromGMT: 0)

        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
