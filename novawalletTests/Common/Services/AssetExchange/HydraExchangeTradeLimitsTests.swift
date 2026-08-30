import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeTradeLimitsTests: XCTestCase {
    func testBoundRejectsZeroRatioRatherThanTrapping() {
        assertRatioUnusable(try HydraExchangeTradeLimits.bound(reserve: 1000, ratio: 0))
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
