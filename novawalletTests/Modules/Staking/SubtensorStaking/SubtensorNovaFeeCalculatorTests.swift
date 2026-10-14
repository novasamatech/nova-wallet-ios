import BigInt
@testable import novawallet
import XCTest

final class SubtensorNovaFeeCalculatorTests: XCTestCase {
    private let beneficiary = Data(repeating: 0xBB, count: 32)

    func testBuyFeeIsTheFlooredShareOfGross() throws {
        let calculator = SubtensorNovaFeeCalculator(beneficiary: beneficiary)

        let fee = try calculator.buyFee(grossTao: 10_000_000_000)

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 29_910_269, beneficiary: beneficiary))
    }

    func testGrossUpOfMinimumStakeIsTheSmallestEntryThatStakesIt() throws {
        let calculator = SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        let minimumStake: Balance = 2_001_007

        let entry = try SubtensorNovaFeeCalculator.grossUp(net: minimumStake)

        let entryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry))
        let smallerEntryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry - 1))
        XCTAssertEqual(entry, 2_007_010)
        XCTAssertEqual(entryFee.amount, 6003)
        XCTAssertEqual(entry - entryFee.amount, minimumStake)
        XCTAssertEqual(entry - 1 - smallerEntryFee.amount, minimumStake - 1)
    }
}
