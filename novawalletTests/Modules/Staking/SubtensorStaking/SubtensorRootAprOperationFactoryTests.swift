import BigInt
@testable import novawallet
import XCTest

final class SubtensorRootAprOperationFactoryTests: XCTestCase {
    func testDecodedTaoWeightWinsOverTheRuntimeDefault() {
        let inputs = SubtensorRootAprOperationFactory.makeInputs(taoWeight: 3_320_413_933_267_719_290)

        XCTAssertEqual(inputs.taoWeight, BigUInt(3_320_413_933_267_719_290))
    }

    func testUnsetTaoWeightFallsBackToTheRuntimeDefault() {
        let inputs = SubtensorRootAprOperationFactory.makeInputs(taoWeight: nil)

        XCTAssertEqual(inputs.taoWeight, SubtensorStakingPallet.defaultTaoWeight)
    }

    func testUnsetTaoWeightNeverCollapsesTheRateToZero() {
        let inputs = SubtensorRootAprOperationFactory.makeInputs(taoWeight: nil)

        XCTAssertGreaterThan(inputs.taoWeight, 0)
    }
}
