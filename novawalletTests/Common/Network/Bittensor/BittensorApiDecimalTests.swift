import XCTest
@testable import novawallet
import BigInt

final class BittensorApiDecimalTests: XCTestCase {
    func testAtomicParsesMaxScaledU64Exactly() throws {
        let atomic = try BittensorApiDecimal.atomic("18446744073.709551615", scale: 9)

        XCTAssertEqual(atomic, BigUInt(UInt64.max))
    }

    func testFractionParsesTakeExactly() throws {
        let fraction = try BittensorApiDecimal.fraction("0.18")

        XCTAssertEqual(fraction, BigRational(numerator: 18, denominator: 100))
    }
}
