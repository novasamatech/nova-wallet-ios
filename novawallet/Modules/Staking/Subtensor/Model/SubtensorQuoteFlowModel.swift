import BigInt
import Foundation

struct SubtensorQuoteFlowModel: Equatable {
    private(set) var request: SubtensorTradeQuoteRequest?
    private(set) var quote: SubtensorTradeQuote?

    mutating func updateRequest(_ newRequest: SubtensorTradeQuoteRequest?) -> SubtensorTradeQuoteRequest? {
        guard newRequest != request else {
            return nil
        }

        request = newRequest
        quote = nil

        return newRequest
    }

    mutating func applyQuote(_ newQuote: SubtensorTradeQuote) -> Bool {
        guard let request, Self.isQuote(newQuote, for: request) else {
            return false
        }

        quote = newQuote

        return true
    }

    mutating func clearQuote() {
        quote = nil
    }

    var freshQuote: SubtensorTradeQuote? {
        guard let request, let quote, Self.isQuote(quote, for: request) else {
            return nil
        }

        return quote
    }
}

private extension SubtensorQuoteFlowModel {
    static func isQuote(_ tradeQuote: SubtensorTradeQuote, for request: SubtensorTradeQuoteRequest) -> Bool {
        guard
            tradeQuote.quote.args.netuid == request.netuid,
            tradeQuote.amountIn == request.amountIn else {
            return false
        }

        let spotPrice = tradeQuote.quote.spotPrice

        switch (request, tradeQuote.quote.args.direction) {
        case let (.buy(_, _, tolerance), .stake):
            return tradeQuote.limitPrice == (try? SubtensorLimitPriceCalculator.buyLimit(
                spot: spotPrice,
                tolerance: tolerance
            ))
        case let (.sell(_, _, tolerance), .unstake):
            return tradeQuote.limitPrice == (try? SubtensorLimitPriceCalculator.sellLimit(
                spot: spotPrice,
                tolerance: tolerance
            ))
        case (.buy, .unstake), (.sell, .stake):
            return false
        }
    }
}
