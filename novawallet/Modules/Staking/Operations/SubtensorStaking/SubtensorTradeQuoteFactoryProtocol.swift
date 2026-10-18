import Foundation
import Operation_iOS

protocol SubtensorTradeQuoteFactoryProtocol: AnyObject {
    func createBuyQuoteWrapper(
        netuid: UInt16,
        grossTao: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote>

    func createSellQuoteWrapper(
        netuid: UInt16,
        alpha: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote>
}
