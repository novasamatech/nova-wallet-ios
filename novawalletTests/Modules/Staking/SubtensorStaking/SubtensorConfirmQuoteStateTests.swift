import BigInt
@testable import novawallet
import XCTest

final class SubtensorConfirmQuoteStateTests: XCTestCase {
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    private var buyRequest: SubtensorTradeQuoteRequest {
        .buy(netuid: 64, grossTao: 5_000_000_000, tolerance: tolerance)
    }

    private func makeBuyQuote(spotPrice: Balance, alphaAmount: Balance) throws -> SubtensorTradeQuote {
        SubtensorTradeQuote(
            quote: SubtensorQuote(
                args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)),
                sim: SubtensorStakingPallet.SimSwapResult(
                    taoAmount: 4_955_361_688,
                    alphaAmount: alphaAmount,
                    taoFee: 2_496_518,
                    alphaFee: 0,
                    taoSlippage: 0,
                    alphaSlippage: 0
                ),
                spotPrice: spotPrice,
                feeRate: 33
            ),
            amountIn: 5_000_000_000,
            novaFee: nil,
            expectedOut: alphaAmount,
            swapMinimumOut: 0,
            minimumOut: 0,
            limitPrice: try SubtensorLimitPriceCalculator.buyLimit(spot: spotPrice, tolerance: tolerance)
        )
    }

    private func makeAcknowledgedQuote() throws -> SubtensorTradeQuote {
        try makeBuyQuote(spotPrice: 73_800_000, alphaAmount: 67_054_958_000)
    }

    private func makeCrossingQuote() throws -> SubtensorTradeQuote {
        try makeBuyQuote(spotPrice: 75_000_000, alphaAmount: 65_983_511_158)
    }

    func testCrossingRequoteKeepsThePriceMovedFlagThroughAFillableRequote() throws {
        let acknowledged = try makeAcknowledgedQuote()
        var state = SubtensorConfirmQuoteState(request: buyRequest, acknowledged: acknowledged)

        XCTAssertTrue(state.apply(latest: try makeCrossingQuote()))
        XCTAssertTrue(state.apply(latest: try makeAcknowledgedQuote()))

        XCTAssertTrue(state.isPriceMoved)
        XCTAssertEqual(state.acknowledged, acknowledged)
    }

    func testAcknowledgingTheLatestRebasesTheLimitAndClearsTheFlag() throws {
        let crossing = try makeCrossingQuote()
        var state = SubtensorConfirmQuoteState(request: buyRequest, acknowledged: try makeAcknowledgedQuote())

        _ = state.apply(latest: crossing)

        XCTAssertTrue(state.acknowledgeLatest())
        XCTAssertFalse(state.isPriceMoved)
        XCTAssertEqual(state.acknowledged?.limitPrice, crossing.limitPrice)
    }

    func testFirstQuoteFillsAMissingAcknowledgedQuoteWithoutTheFlag() throws {
        let crossing = try makeCrossingQuote()
        var state = SubtensorConfirmQuoteState(request: buyRequest, acknowledged: nil)

        XCTAssertTrue(state.apply(latest: crossing))

        XCTAssertFalse(state.isPriceMoved)
        XCTAssertEqual(state.acknowledged, crossing)
    }
}
