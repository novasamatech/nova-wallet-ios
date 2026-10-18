import BigInt
@testable import novawallet
import XCTest

final class BittensorApiDecimalTests: XCTestCase {
    let maxScaledU64 = "18446744073.709551615"
    let maxU256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

    func testAtomicParsesMaxScaledU64Exactly() throws {
        let atomic = try BittensorApiDecimal.atomic(maxScaledU64, scale: 9)

        XCTAssertEqual(atomic, BigUInt(UInt64.max))
    }

    func testDecimalParsesMaxScaledU64Exactly() throws {
        let decimal = try BittensorApiDecimal.decimal(maxScaledU64)

        XCTAssertEqual(decimal, Decimal(sign: .plus, exponent: -9, significand: Decimal(UInt64.max)))
    }

    func testAtomicParsesMaxU256RewardAmountExactly() throws {
        let atomic = try BittensorApiDecimal.atomic(maxU256, scale: 0)

        XCTAssertEqual(atomic, BigUInt(2).power(256) - 1)
    }

    func testDecimalRoundsThirtyDigitFractionHalfUpToDecimalPrecision() throws {
        let decimal = try BittensorApiDecimal.decimal("123456789.123456789012345678901234567895")

        XCTAssertEqual(decimal, Decimal(string: "123456789.1234567890123456789012345679"))
    }

    func testFractionParsesMaxTakeExactly() throws {
        let fraction = try BittensorApiDecimal.fraction("0.18")

        XCTAssertEqual(fraction, BigRational(numerator: 18, denominator: 100))
    }

    func testExponentNotationIsRejectedAsInvalid() {
        XCTAssertThrowsError(try BittensorApiDecimal.decimal("1.5e-7")) { error in
            XCTAssertEqual(error as? BittensorApiDecimalError, .invalid("1.5e-7"))
        }
    }
}
