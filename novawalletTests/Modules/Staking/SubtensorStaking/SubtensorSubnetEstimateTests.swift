@testable import novawallet
import XCTest

final class SubtensorSubnetEstimateTests: XCTestCase {
    func testFiveTaoAtTheChutesSpotHoldsTheExactAlphaAfterTheNovaFee() throws {
        let hold = try XCTUnwrap(SubtensorSubnetEstimate.hold(amountTao: 5_000_000_000, spot: 73_800_000))

        XCTAssertEqual(hold, 67_179_650_487)
    }
}
