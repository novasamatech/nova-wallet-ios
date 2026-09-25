import BigInt
@testable import novawallet
import XCTest

final class SubtensorEarningsEstimatorTests: XCTestCase {
    func testMonthlyEstimateFromChainRateIsExact() throws {
        let annualRate = try XCTUnwrap(BigRational.fraction(from: XCTUnwrap(Decimal(string: "0.031234"))))

        let monthly = SubtensorEarningsEstimator.monthly(amount: 12_000_000_000, annualRate: annualRate)

        XCTAssertEqual(monthly, BigUInt(31_234_000))
    }

    func testMonthlyEstimateRoundsDownToWholeRao() {
        let monthly = SubtensorEarningsEstimator.monthly(
            amount: 1070,
            annualRate: BigRational(numerator: 1, denominator: 10)
        )

        XCTAssertEqual(monthly, BigUInt(8))
    }
}
