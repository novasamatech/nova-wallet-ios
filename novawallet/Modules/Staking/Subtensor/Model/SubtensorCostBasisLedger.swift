import Foundation
import BigInt

struct SubtensorCostBasisLedger {
    static let atomicScale = 9
    static let priceTolerance = BigRational(numerator: 3, denominator: 2)
    static let nonTradeLabelMarkers = ["move", "transfer"]

    private let purchases: [UInt16: SubtensorPurchaseTotals]
    private let unclassifiedNetuids: Set<UInt16>

    init(operations: [BittensorApi.Operation]) {
        var purchases: [UInt16: SubtensorPurchaseTotals] = [:]
        var unclassifiedNetuids: Set<UInt16> = []
        var countedOperations: Set<BittensorApi.Operation> = []

        for operation in operations {
            guard operation.sourceEventId.isEmpty || countedOperations.insert(operation).inserted else {
                continue
            }

            switch Self.classify(operation) {
            case let .purchase(paidTao, receivedAlpha):
                let counted = purchases[operation.netuid]

                purchases[operation.netuid] = SubtensorPurchaseTotals(
                    paidTao: (counted?.paidTao ?? 0) + paidTao,
                    receivedAlpha: (counted?.receivedAlpha ?? 0) + receivedAlpha
                )
            case .unclassified:
                unclassifiedNetuids.insert(operation.netuid)
            case .sale, .ignored:
                break
            }
        }

        self.purchases = purchases
        self.unclassifiedNetuids = unclassifiedNetuids
    }

    func costBasis(for netuid: UInt16) throws -> SubtensorCostBasis {
        guard !unclassifiedNetuids.contains(netuid) else {
            throw SubtensorCostBasisError.unclassifiedOperations(netuid: netuid)
        }

        guard let totals = purchases[netuid] else {
            return .noPurchases
        }

        return .average(totals)
    }
}

private extension SubtensorCostBasisLedger {
    enum Classification {
        case purchase(paidTao: BigUInt, receivedAlpha: BigUInt)
        case sale
        case ignored
        case unclassified
    }

    static func classify(_ operation: BittensorApi.Operation) -> Classification {
        guard
            operation.netuid != SubtensorStakingPallet.rootNetuid,
            !isNonTrade(label: operation.sourceOperationType) else {
            return .ignored
        }

        guard
            let amountIn = atomicMagnitude(of: operation.reportedAmountIn),
            let amountOut = atomicMagnitude(of: operation.reportedAmountOut),
            let price = magnitude(of: operation.reportedPrice) else {
            return .unclassified
        }

        guard amountIn > 0, amountOut > 0, price.numerator > 0 else {
            return .ignored
        }

        let isPurchase = fits(tao: amountIn, alpha: amountOut, price: price)
        let isSale = fits(tao: amountOut, alpha: amountIn, price: price)

        switch (isPurchase, isSale) {
        case (true, false):
            return .purchase(paidTao: amountIn, receivedAlpha: amountOut)
        case (false, true):
            return .sale
        default:
            return .unclassified
        }
    }

    static func isNonTrade(label: String?) -> Bool {
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }

        return nonTradeLabelMarkers.contains { label.contains($0) }
    }

    static func fits(tao: BigUInt, alpha: BigUInt, price: BigRational) -> Bool {
        let reportedTao = tao * price.denominator
        let pricedAlpha = alpha * price.numerator

        return reportedTao * priceTolerance.numerator >= pricedAlpha * priceTolerance.denominator &&
            reportedTao * priceTolerance.denominator <= pricedAlpha * priceTolerance.numerator
    }

    static func magnitude(of value: String) -> BigRational? {
        let unsignedValue = value.hasPrefix("-") ? String(value.dropFirst()) : value

        return try? BittensorApiDecimal.fraction(unsignedValue)
    }

    static func atomicMagnitude(of value: String) -> BigUInt? {
        magnitude(of: value).map { $0.mul(value: BigUInt(10).power(atomicScale)) }
    }
}
