import BigInt
@testable import novawallet
import XCTest

final class SubtensorNovaFeeCalculatorTests: XCTestCase {
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let u64Max = BigUInt(UInt64.max)

    func testBuyFeeAtU64MaxGrossIsFlooredThirtyBasisPoints() throws {
        let fee = try SubtensorNovaFeeCalculator(beneficiary: beneficiary).buyFee(grossTao: u64Max)

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 55_340_232_221_128_654, beneficiary: beneficiary))
    }

    func testBuyAboveU64MaxThrows() {
        XCTAssertThrowsError(try SubtensorNovaFeeCalculator(beneficiary: beneficiary).buyFee(grossTao: u64Max + 1))
    }

    func testSellFeeIsFlooredOnTheLimitGuaranteedMinimumOut() throws {
        let alpha: Balance = 500_000_000_000
        let limitPrice: Balance = 7_644_839

        let minimumTaoOut = try SubtensorNovaFeeCalculator.minimumTaoOut(alpha: alpha, limitPrice: limitPrice)
        let fee = try SubtensorNovaFeeCalculator(beneficiary: beneficiary).sellFee(alpha: alpha, limitPrice: limitPrice)

        XCTAssertEqual(minimumTaoOut, 3_822_419_500)
        XCTAssertEqual(fee, SubtensorNovaFee(amount: 11_467_258, beneficiary: beneficiary))
    }

    func testSellFeeHandlesAlphaTimesPriceBeyondU64() throws {
        let fee = try SubtensorNovaFeeCalculator(beneficiary: beneficiary).sellFee(
            alpha: u64Max,
            limitPrice: 1_000_000_000
        )

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 55_340_232_221_128_654, beneficiary: beneficiary))
    }

    func testSellMinimumOutAboveU64Throws() {
        XCTAssertThrowsError(
            try SubtensorNovaFeeCalculator.minimumTaoOut(alpha: u64Max, limitPrice: 1_000_000_001)
        )
    }

    func testFeeFlooredToZeroIsNotCharged() throws {
        let fee = try SubtensorNovaFeeCalculator(beneficiary: beneficiary).buyFee(grossTao: 333)

        XCTAssertNil(fee)
    }
}
