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

    var tolerance: BigRational {
        switch self {
        case let .buy(_, _, tolerance), let .sell(_, _, tolerance):
            return tolerance
        }
    }

    var direction: SubtensorTradeDirection {
        switch self {
        case .buy:
            return .buy
        case .sell:
            return .sell
        }
    }
}
