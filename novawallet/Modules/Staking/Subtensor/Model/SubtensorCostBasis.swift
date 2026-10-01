import Foundation
import BigInt

struct SubtensorPurchaseTotals: Equatable {
    let paidTao: BigUInt
    let receivedAlpha: BigUInt

    var averagePrice: BigRational {
        BigRational(numerator: paidTao, denominator: receivedAlpha)
    }
}

enum SubtensorCostBasis: Equatable {
    case average(SubtensorPurchaseTotals)
    case noPurchases
}

enum SubtensorCostBasisError: Error, Equatable {
    case unclassifiedOperations(netuid: UInt16)
    case historyTooLong(pageLimit: Int)
    case expiredHistoryPage
}

enum SubtensorCostBasisState: Equatable {
    case loading
    case unavailable
    case resolved(SubtensorCostBasis)
}

enum SubtensorSaleProceeds: Equatable {
    case pending
    case unknown
    case quoted(alpha: Balance, tao: Balance)
}

extension SubtensorSaleProceeds {
    init(quote: SubtensorTradeQuote?, soldAlpha: Balance?, isQuotePending: Bool) {
        if let quote, quote.amountIn == soldAlpha {
            self = .quoted(alpha: quote.amountIn, tao: quote.expectedOut)
        } else {
            self = isQuotePending ? .pending : .unknown
        }
    }
}

extension SubtensorCostBasisState {
    func earnedTao(from proceeds: SubtensorSaleProceeds) -> BigInt? {
        guard
            case let .resolved(.average(totals)) = self,
            case let .quoted(alpha, tao) = proceeds,
            totals.receivedAlpha > 0 else {
            return nil
        }

        return BigInt(tao) - BigInt(totals.averagePrice.mul(value: alpha))
    }
}
