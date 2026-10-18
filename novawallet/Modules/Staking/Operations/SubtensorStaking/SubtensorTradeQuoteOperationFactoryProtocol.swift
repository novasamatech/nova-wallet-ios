import Foundation
import Operation_iOS

protocol SubtensorTradeQuoteOperationFactoryProtocol: AnyObject {
    func createTradeQuoteWrapper(
        for request: SubtensorTradeQuoteRequest
    ) -> CompoundOperationWrapper<SubtensorTradeQuote>
}
