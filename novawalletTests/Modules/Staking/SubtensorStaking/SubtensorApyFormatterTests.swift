@testable import novawallet
import XCTest

final class SubtensorApyFormatterTests: XCTestCase {
    private let hotkey = Data(repeating: 7, count: 32)
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)

    func testFreshYieldFromAFreshSetGivesTheAlphaApy() throws {
        let expectedRate = try XCTUnwrap(Decimal(string: "0.125", locale: Locale(identifier: "en_US_POSIX")))
        let yields = SubtensorAlphaYields(
            netuid: 64,
            yields: [
                hotkey: SubtensorReportedYield(
                    reportedRate: "12.5",
                    stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh)
                )
            ],
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
            isTruncated: false
        )

        XCTAssertEqual(SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields), expectedRate)
    }

    func testStaleYieldHasNoAlphaApy() {
        let yield = SubtensorReportedYield(
            reportedRate: "12.5",
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .stale)
        )

        XCTAssertNil(SubtensorAlphaApyFormatter.annualRate(from: yield))
    }

    func testFreshYieldFromAStaleSetHasNoAlphaApy() {
        let yields = SubtensorAlphaYields(
            netuid: 64,
            yields: [
                hotkey: SubtensorReportedYield(
                    reportedRate: "12.5",
                    stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh)
                )
            ],
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .stale),
            isTruncated: false
        )

        XCTAssertNil(SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields))
    }

    func testColumnHasExactlyOneLocalizedDigitAndSeparatedPercent() {
        XCTAssertEqual(SubtensorApyFormatter.text(for: 0.494, style: .column, locale: Locale(identifier: "en")), "49.4 %")
        let comma = SubtensorApyFormatter.text(for: 0.49, style: .column, locale: Locale(identifier: "de"))
        XCTAssertTrue(comma.contains("49,0"))
        XCTAssertTrue(comma.hasSuffix(" %"))
    }

    func testColumnMovesTurkishPercentPrefixForBothSigns() {
        for identifier in ["tr", "tr_TR"] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(SubtensorApyFormatter.text(for: 0.494, style: .column, locale: locale), "49,4 %")
            XCTAssertEqual(SubtensorApyFormatter.text(for: -0.494, style: .column, locale: locale), "-49,4 %")
        }
    }

    func testColumnPreservesLocalizedDigitsMinusAndDirectionMarks() {
        XCTAssertEqual(
            SubtensorApyFormatter.text(for: -0.494, style: .column, locale: Locale(identifier: "ar_EG")),
            "\u{061C}-٤٩٫٤ ٪\u{061C}"
        )
        XCTAssertEqual(
            SubtensorApyFormatter.text(for: -0.494, style: .column, locale: Locale(identifier: "sv")),
            "−49,4 %"
        )
    }

    func testColumnKeepsHalfEvenRounding() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let roundsDown = try XCTUnwrap(Decimal(string: "0.4945", locale: locale))
        let roundsUp = try XCTUnwrap(Decimal(string: "0.4955", locale: locale))
        XCTAssertEqual(SubtensorApyFormatter.text(for: roundsDown, style: .column, locale: locale), "49.4 %")
        XCTAssertEqual(SubtensorApyFormatter.text(for: roundsUp, style: .column, locale: locale), "49.6 %")
    }

    func testLeadingApyRoundsTheRateDown() throws {
        let annualRate = try XCTUnwrap(Decimal(string: "0.07129", locale: Locale(identifier: "en_US_POSIX")))

        XCTAssertEqual(
            SubtensorApyFormatter.text(for: annualRate, style: .leading, locale: Locale(identifier: "en")),
            "Est. 7.12% APY"
        )
    }
}
