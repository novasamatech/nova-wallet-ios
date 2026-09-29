@testable import novawallet
import XCTest

final class SubtensorSubnetEstimateTests: XCTestCase {
    func testFiveTaoAtTheChutesSpotHoldsAndEarnsTheExactAlphaAfterTheNovaFee() throws {
        let hotkey = Data(repeating: 7, count: 32)
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        let yields = SubtensorAlphaYields(
            netuid: 64,
            yields: [hotkey: SubtensorReportedYield(reportedRate: "38", stamp: stamp)],
            stamp: stamp,
            isTruncated: false
        )

        let hold = try XCTUnwrap(SubtensorSubnetEstimate.hold(amountTao: 5_000_000_000, spot: 73_800_000))
        let annualRate = try XCTUnwrap(SubtensorSubnetEstimate.annualRate(for: hotkey, in: yields))

        XCTAssertEqual(hold, 67_179_650_487)
        XCTAssertEqual(SubtensorSubnetEstimate.monthly(hold: hold, annualRate: annualRate), 2_127_355_598)
    }
}
