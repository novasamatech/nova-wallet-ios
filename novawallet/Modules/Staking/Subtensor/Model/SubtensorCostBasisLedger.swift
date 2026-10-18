import Foundation
import BigInt

struct SubtensorCostBasisLedger {
    static let atomicScale = 9
    static let priceTolerance = BigRational(numerator: 3, denominator: 2)
    static let nonTradeLabelWords: Set<String> = ["move", "transfer"]

    private let openPositions: [UInt16: SubtensorPurchaseTotals]
    private let unclassifiedNetuids: Set<UInt16>
    private let isHistoryComplete: Bool

    init(operations: [BittensorApi.Operation], isHistoryComplete: Bool) {
        var openPositions: [UInt16: SubtensorPurchaseTotals] = [:]
        var unclassifiedNetuids: Set<UInt16> = []
        var countedOperations: Set<BittensorApi.Operation> = []

        for operation in operations.reversed() {
            guard operation.sourceEventId.isEmpty || countedOperations.insert(operation).inserted else {
                continue
            }

            let openPosition = openPositions[operation.netuid]

            switch Self.classify(operation) {
            case let .purchase(paidTao, receivedAlpha):
                let purchase = SubtensorPurchaseTotals(paidTao: paidTao, receivedAlpha: receivedAlpha)

                openPositions[operation.netuid] = openPosition?.adding(
                    paidTao: paidTao,
                    receivedAlpha: receivedAlpha
                ) ?? purchase
            case let .sale(soldAlpha):
                openPositions[operation.netuid] = openPosition?.reducing(soldAlpha: soldAlpha)
            case .unclassified:
                unclassifiedNetuids.insert(operation.netuid)
            case .ignored:
                break
            }
        }

        self.openPositions = openPositions
        self.unclassifiedNetuids = unclassifiedNetuids
        self.isHistoryComplete = isHistoryComplete
    }

    func costBasis(for netuid: UInt16) throws -> SubtensorCostBasis {
        guard isHistoryComplete else {
            return .noPurchases
        }

        guard !unclassifiedNetuids.contains(netuid) else {
            throw SubtensorCostBasisError.unclassifiedOperations(netuid: netuid)
        }

        guard let openPosition = openPositions[netuid] else {
            return .noPurchases
        }

        return .average(openPosition)
    }
}

private extension SubtensorCostBasisLedger {
    enum Classification {
        case purchase(paidTao: BigUInt, receivedAlpha: BigUInt)
        case sale(soldAlpha: BigUInt)
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
            return .sale(soldAlpha: amountIn)
        default:
            return .unclassified
        }
    }

    static func isNonTrade(label: String?) -> Bool {
        guard let label else {
            return false
        }

        return label
            .split { !$0.isLetter }
            .flatMap { camelCaseWords(in: Array($0)) }
            .contains { nonTradeLabelWords.contains($0.lowercased()) }
    }

    static func camelCaseWords(in letters: [Character]) -> [String] {
        var words: [String] = []
        var wordStart = 0

        for index in letters.indices.dropFirst() where startsCamelCaseWord(at: index, in: letters) {
            words.append(String(letters[wordStart ..< index]))
            wordStart = index
        }

        words.append(String(letters[wordStart...]))

        return words
    }

    static func startsCamelCaseWord(at index: Int, in letters: [Character]) -> Bool {
        let previous = letters[index - 1]
        let precedesLowercase = letters.indices.contains(index + 1) && letters[index + 1].isLowercase

        return letters[index].isUppercase && (previous.isLowercase || (previous.isUppercase && precedesLowercase))
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
