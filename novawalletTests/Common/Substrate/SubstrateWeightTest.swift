import XCTest
@testable import novawallet

final class SubstrateWeightTest: XCTestCase {
    func testSum() {
        // given
        let weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 5, proofSize: 4)
        let expected = Substrate.Weight(refTime: 7, proofSize: 5)

        // then

        XCTAssertEqual(expected, weight1 + weight2)
    }

    func testSumWithAssignment() {
        // given
        var weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 5, proofSize: 4)
        let expected = Substrate.Weight(refTime: 7, proofSize: 5)

        // when
        weight1 += weight2

        // then

        XCTAssertEqual(expected, weight1)
    }

    func testMinusWithoutOverflow() {
        // given
        let weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 3, proofSize: 4)
        let expected = Substrate.Weight(refTime: 1, proofSize: 3)

        // then

        XCTAssertEqual(expected, weight2 - weight1)
    }

    func testMinusWithOverflow() {
        // given
        let weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 3, proofSize: 4)

        // then

        XCTAssertEqual(.zero, weight1 - weight2)
    }

    func testMinWhenBothComponentLess() {
        // given
        let weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 3, proofSize: 4)

        // then

        XCTAssertEqual(weight1, weight1.minByComponent(with: weight2))
    }

    func testMinWhenFirstComponentLess() {
        // given
        let weight1 = Substrate.Weight(refTime: 2, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 3, proofSize: 0)
        let expected = Substrate.Weight(refTime: 2, proofSize: 0)

        // then

        XCTAssertEqual(expected, weight1.minByComponent(with: weight2))
    }

    func testMinWhenSecondComponentLess() {
        // given
        let weight1 = Substrate.Weight(refTime: 3, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 2, proofSize: 4)
        let expected = Substrate.Weight(refTime: 2, proofSize: 1)

        // then

        XCTAssertEqual(expected, weight1.minByComponent(with: weight2))
    }

    func testMulRational() {
        // given
        let weight1 = Substrate.Weight(refTime: 1000, proofSize: 101)
        let multiplier = BigRational.percent(of: 8)
        let expected = Substrate.Weight(refTime: 80, proofSize: 8)

        // then

        XCTAssertEqual(expected, weight1 * multiplier)
    }

    func testAnyGt() {
        // given
        let weight1 = Substrate.Weight(refTime: 3, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 2, proofSize: 4)
        let weight3 = Substrate.Weight(refTime: 2, proofSize: 0)

        XCTAssertTrue(weight1.anyGt(then: weight2))
        XCTAssertTrue(weight1.anyGt(then: weight3))
        XCTAssertFalse(weight3.anyGt(then: weight1))
        XCTAssertFalse(weight3.anyGt(then: weight2))
    }

    func testFittings() {
        // given
        let weight1 = Substrate.Weight(refTime: 3, proofSize: 1)
        let weight2 = Substrate.Weight(refTime: 2, proofSize: 4)
        let weight3 = Substrate.Weight(refTime: 2, proofSize: 0)

        XCTAssertFalse(weight1.fits(in: weight2))
        XCTAssertFalse(weight2.fits(in: weight1))
        XCTAssertTrue(weight3.fits(in: weight1))
        XCTAssertTrue(weight3.fits(in: weight2))
    }
}
