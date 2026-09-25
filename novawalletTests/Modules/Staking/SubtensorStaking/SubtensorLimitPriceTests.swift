import BigInt
@testable import novawallet
import XCTest

final class SubtensorLimitPriceTests: XCTestCase {
    let liveSpot = BigUInt(7_683_255)
    let maxU64Spot = BigUInt(UInt64.max)
    let rootSpot = SubtensorStakingPallet.alphaPriceScale

    func testDefaultToleranceIsHalfPercent() {
        XCTAssertEqual(
            SubtensorSlippageTolerance.defaultTolerance,
            BigRational(numerator: 5, denominator: 1000)
        )
    }

    func testPresetsAreTenthHalfOneAndThreePercent() {
        XCTAssertEqual(
            SubtensorSlippageTolerance.presets,
            [
                BigRational(numerator: 1, denominator: 1000),
                BigRational(numerator: 5, denominator: 1000),
                BigRational(numerator: 1, denominator: 100),
                BigRational(numerator: 3, denominator: 100)
            ]
        )
    }

    func testDefaultToleranceIsAPreset() {
        XCTAssertTrue(
            SubtensorSlippageTolerance.presets.contains(SubtensorSlippageTolerance.defaultTolerance)
        )
    }

    func testBuyLimitAppliesEveryPresetWithFloorRounding() throws {
        let expectedLimits: [BigUInt] = [7_690_938, 7_721_671, 7_760_087, 7_913_752]

        let limits = try SubtensorSlippageTolerance.presets.map { tolerance in
            try SubtensorLimitPriceCalculator.buyLimit(spot: liveSpot, tolerance: tolerance)
        }

        XCTAssertEqual(limits, expectedLimits)
    }

    func testSellLimitAppliesEveryPresetWithCeilRounding() throws {
        let expectedLimits: [BigUInt] = [7_675_572, 7_644_839, 7_606_423, 7_452_758]

        let limits = try SubtensorSlippageTolerance.presets.map { tolerance in
            try SubtensorLimitPriceCalculator.sellLimit(spot: liveSpot, tolerance: tolerance)
        }

        XCTAssertEqual(limits, expectedLimits)
    }

    func testBuyLimitFloorsWhereNaiveRoundingWouldRoundUp() throws {
        let limit = try SubtensorLimitPriceCalculator.buyLimit(
            spot: 999,
            tolerance: BigRational(numerator: 5, denominator: 1000)
        )

        XCTAssertEqual(limit, 1003)
    }

    func testSellLimitCeilsWhereNaiveRoundingWouldRoundDown() throws {
        let limit = try SubtensorLimitPriceCalculator.sellLimit(
            spot: 999,
            tolerance: BigRational(numerator: 5, denominator: 1000)
        )

        XCTAssertEqual(limit, 995)
    }

    func testBuyLimitAtZeroToleranceIsSpotPlusOne() throws {
        let limit = try SubtensorLimitPriceCalculator.buyLimit(
            spot: 1000,
            tolerance: BigRational(numerator: 0, denominator: 1000)
        )

        XCTAssertEqual(limit, 1001)
    }

    func testSellLimitAtZeroToleranceIsSpotMinusOne() throws {
        let limit = try SubtensorLimitPriceCalculator.sellLimit(
            spot: 1000,
            tolerance: BigRational(numerator: 0, denominator: 1000)
        )

        XCTAssertEqual(limit, 999)
    }

    func testBuyLimitClampsToSpotPlusOneWhenToleranceFloorsToZero() throws {
        let limit = try SubtensorLimitPriceCalculator.buyLimit(
            spot: 100,
            tolerance: BigRational(numerator: 1, denominator: 1000)
        )

        XCTAssertEqual(limit, 101)
    }

    func testSellLimitClampsToSpotMinusOneWhenCeilLandsOnSpot() throws {
        let limit = try SubtensorLimitPriceCalculator.sellLimit(
            spot: 100,
            tolerance: BigRational(numerator: 1, denominator: 1000)
        )

        XCTAssertEqual(limit, 99)
    }

    func testSellLimitAtUnitSpotThrowsInsteadOfZero() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.sellLimit(
                spot: 1,
                tolerance: SubtensorSlippageTolerance.defaultTolerance
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .zeroLimit)
        }
    }

    func testBuyLimitOverflowingU64Throws() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.buyLimit(
                spot: maxU64Spot,
                tolerance: BigRational(numerator: 1, denominator: 1000)
            )
        ) { error in
            guard case SubtensorStakingCallError.amountExceedsMaxU64 = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testBuyLimitAtMaxSpotThrowsEvenAtZeroTolerance() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.buyLimit(
                spot: maxU64Spot,
                tolerance: BigRational(numerator: 0, denominator: 1)
            )
        )
    }

    func testSellLimitAtMaxSpotStaysWithinU64() throws {
        let limit = try SubtensorLimitPriceCalculator.sellLimit(
            spot: maxU64Spot,
            tolerance: SubtensorSlippageTolerance.defaultTolerance
        )

        XCTAssertEqual(limit, BigUInt(18_354_510_353_341_003_857 as UInt64))
        XCTAssertLessThanOrEqual(limit, BigUInt(UInt64.max))
    }

    func testZeroSpotThrowsOnBuySide() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.buyLimit(
                spot: 0,
                tolerance: SubtensorSlippageTolerance.defaultTolerance
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .zeroSpot)
        }
    }

    func testZeroSpotThrowsOnSellSide() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.sellLimit(
                spot: 0,
                tolerance: SubtensorSlippageTolerance.defaultTolerance
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .zeroSpot)
        }
    }

    func testSellToleranceAtFullThrows() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.sellLimit(
                spot: liveSpot,
                tolerance: BigRational(numerator: 1, denominator: 1)
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .invalidTolerance)
        }
    }

    func testSellToleranceAboveFullThrows() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.sellLimit(
                spot: liveSpot,
                tolerance: BigRational(numerator: 1001, denominator: 1000)
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .invalidTolerance)
        }
    }

    func testZeroDenominatorToleranceThrowsOnBuySide() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.buyLimit(
                spot: liveSpot,
                tolerance: BigRational(numerator: 1, denominator: 0)
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .invalidTolerance)
        }
    }

    func testZeroDenominatorToleranceThrowsOnSellSide() {
        XCTAssertThrowsError(
            try SubtensorLimitPriceCalculator.sellLimit(
                spot: liveSpot,
                tolerance: BigRational(numerator: 1, denominator: 0)
            )
        ) { error in
            XCTAssertEqual(error as? SubtensorLimitPriceError, .invalidTolerance)
        }
    }

    func testRootSpotBuyLimitAlwaysPassesStrictBuyGate() throws {
        for tolerance in SubtensorSlippageTolerance.presets {
            let limit = try SubtensorLimitPriceCalculator.buyLimit(spot: rootSpot, tolerance: tolerance)

            XCTAssertGreaterThan(limit, rootSpot)
        }
    }

    func testRootSpotSellLimitAlwaysPassesStrictSellGate() throws {
        for tolerance in SubtensorSlippageTolerance.presets {
            let limit = try SubtensorLimitPriceCalculator.sellLimit(spot: rootSpot, tolerance: tolerance)

            XCTAssertLessThan(limit, rootSpot)
        }
    }

    func testRootSpotBuyLimitAtZeroToleranceStaysStrictlyAboveSpot() throws {
        let limit = try SubtensorLimitPriceCalculator.buyLimit(
            spot: rootSpot,
            tolerance: BigRational(numerator: 0, denominator: 1)
        )

        XCTAssertEqual(limit, rootSpot + 1)
    }

    func testRootSpotSellLimitAtZeroToleranceStaysStrictlyBelowSpot() throws {
        let limit = try SubtensorLimitPriceCalculator.sellLimit(
            spot: rootSpot,
            tolerance: BigRational(numerator: 0, denominator: 1)
        )

        XCTAssertEqual(limit, rootSpot - 1)
    }
}
