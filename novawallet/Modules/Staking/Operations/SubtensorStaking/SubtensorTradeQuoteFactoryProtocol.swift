import Foundation
import Operation_iOS

protocol SubtensorTradeQuoteFactoryProtocol: AnyObject {
    func createTradeQuoteWrapper(
        for request: SubtensorTradeQuoteRequest
    ) -> CompoundOperationWrapper<SubtensorTradeQuote>
}
