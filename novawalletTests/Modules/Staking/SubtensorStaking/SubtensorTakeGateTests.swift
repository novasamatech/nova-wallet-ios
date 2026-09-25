import XCTest
@testable import novawallet

final class SubtensorTakeGateTests: XCTestCase {
    let maxTake = BigRational(numerator: 20, denominator: 100)

    func testTakeExactlyEqualToMaxTakeDoesNotExceedIt() {
        XCTAssertFalse(SubtensorTakeGate.exceedsMax(take: 13107, maxTake: maxTake))
    }

    func testTakeOneUnitAboveMaxTakeExceedsIt() {
        XCTAssertTrue(SubtensorTakeGate.exceedsMax(take: 13108, maxTake: maxTake))
    }
}
