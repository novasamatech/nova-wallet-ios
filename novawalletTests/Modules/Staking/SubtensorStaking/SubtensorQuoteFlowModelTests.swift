import BigInt
@testable import novawallet
import XCTest

final class SubtensorQuoteFlowModelTests: XCTestCase {
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    private var buyRequest: SubtensorTradeQuoteRequest {
        .buy(netuid: 64, grossTao: 5_000_000_000, tolerance: tolerance)
    }

    private func makeBuyQuote(
        netuid: UInt16 = 64,
        amountIn: Balance = 5_000_000_000,
        limitPrice: Balance = 74_169_000
    ) -> SubtensorTradeQuote {
        SubtensorTradeQuote(
            quote: SubtensorQuote(
                args: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: 4_957_858_206)),
                sim: SubtensorStakingPallet.SimSwapResult(
                    taoAmount: 4_955_361_688,
                    alphaAmount: 67_054_958_000,
                    taoFee: 2_496_518,
                    alphaFee: 0,
                    taoSlippage: 0,
                    alphaSlippage: 0
                ),
                spotPrice: 73_800_000,
                feeRate: 33,
                capturedAt: Date(timeIntervalSince1970: 1_790_000_000)
            ),
            amountIn: amountIn,
            novaFee: nil,
            expectedOut: 67_054_958_000,
            swapMinimumOut: 66_811_763_513,
            minimumOut: 66_811_763_513,
            limitPrice: limitPrice
        )
    }

    func testChangingTheRequestRequestsARefreshAndClearsTheQuote() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)
        XCTAssertTrue(model.applyQuote(makeBuyQuote()))

        let newRequest = SubtensorTradeQuoteRequest.buy(netuid: 64, grossTao: 6_000_000_000, tolerance: tolerance)

        XCTAssertEqual(model.updateRequest(newRequest), newRequest)
        XCTAssertNil(model.freshQuote)
    }

    func testUnchangedRequestRequestsNoRefresh() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)

        XCTAssertNil(model.updateRequest(buyRequest))
    }

    func testQuoteForAnotherSubnetIsRejected() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)

        XCTAssertFalse(model.applyQuote(makeBuyQuote(netuid: 12)))
        XCTAssertNil(model.freshQuote)
    }

    func testQuoteForAnotherAmountIsRejected() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)

        XCTAssertFalse(model.applyQuote(makeBuyQuote(amountIn: 6_000_000_000)))
        XCTAssertNil(model.freshQuote)
    }

    func testQuoteLimitedAtAnotherToleranceIsRejected() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)

        XCTAssertFalse(model.applyQuote(makeBuyQuote(limitPrice: 74_538_000)))
        XCTAssertNil(model.freshQuote)
    }

    func testMatchingQuoteBecomesFresh() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)

        XCTAssertTrue(model.applyQuote(makeBuyQuote()))
        XCTAssertEqual(model.freshQuote, makeBuyQuote())
    }

    func testClearingTheRequestDropsTheQuote() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)
        _ = model.applyQuote(makeBuyQuote())

        XCTAssertNil(model.updateRequest(nil))
        XCTAssertNil(model.freshQuote)
        XCTAssertNil(model.request)
    }

    func testClearQuoteDropsTheQuoteButKeepsTheRequest() {
        var model = SubtensorQuoteFlowModel()
        _ = model.updateRequest(buyRequest)
        _ = model.applyQuote(makeBuyQuote())

        model.clearQuote()

        XCTAssertNil(model.freshQuote)
        XCTAssertEqual(model.request, buyRequest)
    }
}
