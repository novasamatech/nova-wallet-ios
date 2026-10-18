import Foundation

enum SubtensorTradeQuoteRequest: Equatable {
    case buy(netuid: UInt16, grossTao: Balance, tolerance: BigRational)
    case sell(netuid: UInt16, alpha: Balance, tolerance: BigRational)
}

extension SubtensorTradeQuoteRequest {
    var netuid: UInt16 {
        switch self {
        case let .buy(netuid, _, _), let .sell(netuid, _, _):
            return netuid
        }
    }

    var amountIn: Balance {
        switch self {
        case let .buy(_, grossTao, _):
            return grossTao
        case let .sell(_, alpha, _):
            return alpha
        }
    }
}
