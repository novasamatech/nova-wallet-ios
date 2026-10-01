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
