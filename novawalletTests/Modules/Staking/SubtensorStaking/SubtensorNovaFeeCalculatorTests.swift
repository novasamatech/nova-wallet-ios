import BigInt
@testable import novawallet
import XCTest

final class SubtensorNovaFeeCalculatorTests: XCTestCase {
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let u64Max = BigUInt(UInt64.max)

    private var calculator: SubtensorNovaFeeCalculator {
        SubtensorNovaFeeCalculator(beneficiary: beneficiary)
    }

    func testBuyFeeOnTenTaoIsTheFlooredShareOfGross() throws {
        let fee = try calculator.buyFee(grossTao: 10_000_000_000)

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 84_283_589, beneficiary: beneficiary))
    }

    func testSellFeeOnTheQuotedTaoOutIsTheFlooredShareOfGross() throws {
        let fee = try calculator.sellFee(quotedTaoOut: 4_145_000_000)

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 34_935_547, beneficiary: beneficiary))
    }

    func testZeroBasisChargesNoFee() throws {
        XCTAssertNil(try calculator.buyFee(grossTao: 0))
        XCTAssertNil(try calculator.sellFee(quotedTaoOut: 0))
    }

    func testFeeFloorsToNothingAt118RaoAndChargesOneRaoAt119() throws {
        XCTAssertNil(try calculator.buyFee(grossTao: 118))
        XCTAssertEqual(try calculator.buyFee(grossTao: 119), SubtensorNovaFee(amount: 1, beneficiary: beneficiary))
    }

    func testBuyFeeAtU64MaxGross() throws {
        let fee = try calculator.buyFee(grossTao: u64Max)

        XCTAssertEqual(fee, SubtensorNovaFee(amount: 155_475_780_492_346_245, beneficiary: beneficiary))
    }

    func testBuyAboveU64MaxThrows() {
        XCTAssertThrowsError(try calculator.buyFee(grossTao: u64Max + 1))
    }

    func testSellMinimumOutHandlesAlphaTimesPriceBeyondU64() throws {
        let minimumTaoOut = try SubtensorNovaFeeCalculator.minimumTaoOut(alpha: u64Max, limitPrice: 1_000_000_000)

        XCTAssertEqual(minimumTaoOut, u64Max)
    }

    func testSellMinimumOutAboveU64Throws() {
        XCTAssertThrowsError(
            try SubtensorNovaFeeCalculator.minimumTaoOut(alpha: u64Max, limitPrice: 1_000_000_001)
        )
    }

    func testGrossUpOfTheMinimumStakeIsTheSmallestEntryThatStakesIt() throws {
        let minimumStake: Balance = 2_001_007

        let entry = try SubtensorNovaFeeCalculator.grossUp(net: minimumStake)
        let entryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry))
        let smallerEntryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry - 1))

        XCTAssertEqual(entry, 2_018_015)
        XCTAssertEqual(entryFee.amount, 17008)
        XCTAssertEqual(entry - entryFee.amount, minimumStake)
        XCTAssertEqual(entry - 1 - smallerEntryFee.amount, minimumStake - 1)
    }

    func testGrossUpStaysTheSmallestEntryWhereAddingTheRateOvershootsByOneRao() throws {
        let entry = try SubtensorNovaFeeCalculator.grossUp(net: 2000)
        let entryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry))
        let smallerEntryFee = try XCTUnwrap(try calculator.buyFee(grossTao: entry - 1))

        XCTAssertEqual(entry, 2016)
        XCTAssertEqual(entry - entryFee.amount, 2000)
        XCTAssertEqual(entry - 1 - smallerEntryFee.amount, 1999)
    }

    func testDefaultBeneficiaryIsTheProductionAccount() throws {
        let production = try Data(hexString: "0x5d11a510a9bef3fae089b0500483f53498b6c5e616ff0027e37c1f1e84bb1565")

        XCTAssertEqual(SubtensorNovaFeeCalculator.defaultBeneficiary, production)
        XCTAssertEqual(SubtensorNovaFeeCalculator().beneficiary, production)
    }
}
