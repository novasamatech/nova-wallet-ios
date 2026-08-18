import XCTest
@testable import novawallet
import BigInt

final class BigRationalFixedPointTests: XCTestCase {
    func testFromRationalRoundsTiesDown() {

        XCTAssertEqual(
            BigRational(numerator: 1, denominator: 400_000_000_000_000_000).toFixedU128Inner(),
            2
        )
        XCTAssertEqual(
            BigRational(numerator: 3, denominator: 400_000_000_000_000_000).toFixedU128Inner(),
            7
        )
    }

    func testFromRationalRoundsUpOnlyWhenStrictlyPastHalf() {
        XCTAssertEqual(
            BigRational(numerator: 1, denominator: 3).toFixedU128Inner(),
            BigUInt("333333333333333333")
        )
        XCTAssertEqual(
            BigRational(numerator: 2, denominator: 3).toFixedU128Inner(),
            BigUInt("666666666666666667")
        )
    }

    func testFromRationalExactValueNeedsNoRounding() {
        XCTAssertEqual(
            BigRational(numerator: 6, denominator: 5).toFixedU128Inner(),
            BigUInt("1200000000000000000")
        )
    }

    func testFromRationalZeroDenominatorReturnsNil() {
        XCTAssertNil(BigRational(numerator: 1, denominator: 0).toFixedU128Inner())
    }

    func testFromRationalOverflowingU128ReturnsNil() {
        XCTAssertNil(BigRational(numerator: BigUInt(1) << 200, denominator: 1).toFixedU128Inner())
    }

    func testInvertedPreservesZero() {
        let zero = BigRational(numerator: 0, denominator: 7)

        XCTAssertEqual(zero.inverted, zero)
    }

    func testInvertedSwapsTerms() {
        XCTAssertEqual(
            BigRational(numerator: 3, denominator: 5).inverted,
            BigRational(numerator: 5, denominator: 3)
        )
    }

    func testExactMultiplyDoesNotReduce() {
        let product = BigRational(numerator: 2, denominator: 1)
            .mul(BigRational(numerator: 3, denominator: 5))

        XCTAssertEqual(product, BigRational(numerator: 6, denominator: 5))
    }

    func testConvertFeeTruncates() {
        let price = HydraFeeConversion.Price(inner: BigUInt("1200000000000000000"))

        XCTAssertEqual(
            HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price),
            BigUInt("1200000000000")
        )
    }

    func testConvertFeeAppliesOnePlankFloor() {
        let price = HydraFeeConversion.Price(inner: 0)

        XCTAssertEqual(HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price), 1)
    }

    func testConvertZeroFeeStaysZero() {
        XCTAssertEqual(HydraFeeConversion.convertFee(0, price: .one), 0)
        XCTAssertEqual(HydraFeeConversion.convertFee(0, price: .init(inner: 0)), 0)
    }

    func testConvertFeeWithUnitPrice() {
        XCTAssertEqual(HydraFeeConversion.convertFee(BigUInt("12345"), price: .one), 12345)
    }
}
