import XCTest
@testable import novawallet
import BigInt

final class HydraFeeConversionTests: XCTestCase {
    func testFromRationalRoundsTiesDown() {
        XCTAssertEqual(
            HydraFeeConversion.Price(rational: .init(numerator: 1, denominator: 400_000_000_000_000_000))?.inner,
            2
        )
        XCTAssertEqual(
            HydraFeeConversion.Price(rational: .init(numerator: 3, denominator: 400_000_000_000_000_000))?.inner,
            7
        )
    }

    func testFromRationalRoundsUpOnlyWhenStrictlyPastHalf() {
        XCTAssertEqual(
            HydraFeeConversion.Price(rational: .init(numerator: 1, denominator: 3))?.inner,
            BigUInt("333333333333333333")
        )
        XCTAssertEqual(
            HydraFeeConversion.Price(rational: .init(numerator: 2, denominator: 3))?.inner,
            BigUInt("666666666666666667")
        )
    }

    func testFromRationalExactValueNeedsNoRounding() {
        XCTAssertEqual(
            HydraFeeConversion.Price(rational: .init(numerator: 6, denominator: 5))?.inner,
            BigUInt("1200000000000000000")
        )
    }

    func testFromRationalZeroDenominatorReturnsNil() {
        XCTAssertNil(HydraFeeConversion.Price(rational: .init(numerator: 1, denominator: 0)))
    }

    func testFromRationalOverflowingU128ReturnsNil() {
        XCTAssertNil(HydraFeeConversion.Price(rational: .init(numerator: BigUInt(1) << 200, denominator: 1)))
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
