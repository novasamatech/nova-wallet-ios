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

enum SubtensorAvgBuyPriceTrend: Equatable {
    case rising
    case falling
    case unchanged
}

enum SubtensorPurchaseQuote: Equatable {
    case empty
    case pending
    case unknown
    case quoted(tao: Balance, alpha: Balance)
}

extension SubtensorPurchaseQuote {
    init(quote: SubtensorTradeQuote?, paidTao: Balance?, isQuotePending: Bool) {
        guard let paidTao, paidTao > 0 else {
            self = .empty
            return
        }

        if let quote, quote.amountIn == paidTao {
            self = .quoted(tao: quote.amountIn, alpha: quote.expectedOut)
        } else {
            self = isQuotePending ? .pending : .unknown
        }
    }
}

extension SubtensorPurchaseTotals {
    func adding(paidTao: Balance, receivedAlpha: Balance) -> SubtensorPurchaseTotals {
        SubtensorPurchaseTotals(
            paidTao: self.paidTao + paidTao,
            receivedAlpha: self.receivedAlpha + receivedAlpha
        )
    }

    func reducing(soldAlpha: Balance) -> SubtensorPurchaseTotals? {
        guard soldAlpha < receivedAlpha else {
            return nil
        }

        let remainingAlpha = receivedAlpha - soldAlpha
        let remainingTao = BigRational(numerator: remainingAlpha, denominator: receivedAlpha).mul(value: paidTao)

        guard remainingTao > 0 else {
            return nil
        }

        return SubtensorPurchaseTotals(paidTao: remainingTao, receivedAlpha: remainingAlpha)
    }

    func averageTrend(to other: SubtensorPurchaseTotals) -> SubtensorAvgBuyPriceTrend {
        let currentAverage = paidTao * other.receivedAlpha
        let otherAverage = other.paidTao * receivedAlpha

        if otherAverage > currentAverage {
            return .rising
        }

        if otherAverage < currentAverage {
            return .falling
        }

        return .unchanged
    }
}
