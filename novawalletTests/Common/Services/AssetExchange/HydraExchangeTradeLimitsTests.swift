import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeTradeLimitsTests: XCTestCase {
    func testBoundUsesIntegerFloorDivision() throws {
        XCTAssertEqual(try HydraExchangeTradeLimits.bound(reserve: 1000, ratio: 3), 333)
        XCTAssertEqual(try HydraExchangeTradeLimits.bound(reserve: 2, ratio: 3), 0)
    }

    func testBoundRejectsZeroRatioRatherThanTrapping() {
        assertRatioUnusable(try HydraExchangeTradeLimits.bound(reserve: 1000, ratio: 0))
    }

    func testValidationReportsRatioUnusableRatherThanALimitBreachOnZeroRatio() {
        assertRatioUnusable(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 1,
                amountOutPreFee: 1,
                reserveIn: 3000,
                reserveOut: 3000,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 0, maxOutRatio: 3)
            )
        )
    }

    func testXYKSellAcceptsAmountInAtTheInRatioBoundAndRejectsOneMore() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 1000,
                amountOutPreFee: 750,
                reserveIn: 3000,
                reserveOut: 3000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 1001,
                amountOutPreFee: 750,
                reserveIn: 3000,
                reserveOut: 3000,
                ratios: ratios
            )
        )
    }

    func testXYKSellAcceptsPreFeeOutputAtTheOutRatioBoundAndRejectsTheNextAmountIn() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 2, maxOutRatio: 4)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 333,
                amountOutPreFee: 24981,
                reserveIn: 1000,
                reserveOut: 100_000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 334,
                amountOutPreFee: 25037,
                reserveIn: 1000,
                reserveOut: 100_000,
                ratios: ratios
            )
        )
    }

    func testXYKSellRejectsPreFeeOutputWhosePostFeeQuoteWouldFitTheOutRatioBound() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 2, maxOutRatio: 4)

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 334,
                amountOutPreFee: 25037,
                reserveIn: 1000,
                reserveOut: 100_000,
                ratios: ratios
            )
        )

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKSell(
                amountIn: 334,
                amountOutPreFee: 24962,
                reserveIn: 1000,
                reserveOut: 100_000,
                ratios: ratios
            )
        )
    }

    func testXYKBuyAcceptsAmountOutAtTheOutRatioBoundAndRejectsOneMore() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 5)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 100_000,
                amountInPreFee: 75001,
                reserveIn: 300_000,
                reserveOut: 500_000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 100_001,
                amountInPreFee: 75001,
                reserveIn: 300_000,
                reserveOut: 500_000,
                ratios: ratios
            )
        )
    }

    func testXYKBuyRejectsTheAmountOutAndroidsFloorCapWouldAccept() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 249,
                amountInPreFee: 995,
                reserveIn: 3000,
                reserveOut: 1000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 250,
                amountInPreFee: 1001,
                reserveIn: 3000,
                reserveOut: 1000,
                ratios: ratios
            )
        )
    }

    func testXYKBuyAcceptsPreFeeInputWhoseFeeInclusiveQuoteWouldExceedTheInRatioBound() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 249_999,
                amountInPreFee: 100_000,
                reserveIn: 300_000,
                reserveOut: 1_000_000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateXYKBuy(
                amountOut: 249_999,
                amountInPreFee: 100_300,
                reserveIn: 300_000,
                reserveOut: 1_000_000,
                ratios: ratios
            )
        )
    }

    func testOmnipoolAcceptsTradeInsideBothBounds() {
        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: 250_000,
                amountOut: 150_000,
                reserveIn: 900_000,
                reserveOut: 600_000,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
            )
        )
    }

    func testOmnipoolRejectsOutputAboveTheOutRatioBoundEvenWhenInputFits() {
        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: 250_000,
                amountOut: 210_000,
                reserveIn: 900_000,
                reserveOut: 600_000,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
            )
        )
    }

    func testOmnipoolRejectsInputAboveTheInRatioBoundEvenWhenOutputFits() {
        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: 320_000,
                amountOut: 150_000,
                reserveIn: 900_000,
                reserveOut: 600_000,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
            )
        )
    }

    func testOmnipoolAppliesEachRatioToItsOwnSideOfThePool() {
        let ratios = HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 6)

        XCTAssertNoThrow(
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: 250_000,
                amountOut: 90000,
                reserveIn: 900_000,
                reserveOut: 600_000,
                ratios: ratios
            )
        )

        assertExceedsPoolTradeLimit(
            try HydraExchangeTradeLimits.validateOmnipool(
                amountIn: 120_000,
                amountOut: 180_000,
                reserveIn: 900_000,
                reserveOut: 600_000,
                ratios: ratios
            )
        )
    }
}

private extension HydraExchangeTradeLimitsTests {
    func assertExceedsPoolTradeLimit<T>(
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case HydraExchangeTradeLimitError.exceedsPoolTradeLimit = error else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
        }
    }

    func assertRatioUnusable<T>(
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case HydraExchangeTradeLimitError.ratioUnusable = error else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
        }
    }
}
