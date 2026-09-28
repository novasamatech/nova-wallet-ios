import XCTest
import Foundation_iOS
@testable import novawallet

final class NumberFormatterPercentTests: XCTestCase {
    func testDefaultValidatorTakeFormatsAsEighteenPercent() {
        let take = Decimal(11796) / Decimal(SubtensorStakingPallet.perU16Denominator)

        let formatter = NumberFormatter.percentSingleHalfEven
            .localizableResource()
            .value(for: Locale(identifier: "en_US"))

        XCTAssertEqual(formatter.stringFromDecimal(take), "18%")
    }
}
