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

    func testLeadingApyRoundsTheRateDown() throws {
        let annualRate = try XCTUnwrap(Decimal(string: "0.07129", locale: Locale(identifier: "en_US_POSIX")))

        XCTAssertEqual(
            SubtensorApyFormatter.text(for: annualRate, style: .leading, locale: Locale(identifier: "en")),
            "APY 7.12%"
        )
    }
}
