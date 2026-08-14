import Foundation

struct AssetExchangeCommissionNetFlow {
    private let netAmountsIn: [Balance]
    private let netAmountsOut: [Balance]

    init(operations: [AssetExchangeMetaOperationProtocol], commission: AssetExchangeCommission?) {
        var amountsIn: [Balance] = []
        var amountsOut: [Balance] = []

        var deduction: Balance = 0

        for (index, operation) in operations.enumerated() {
            amountsIn.append(operation.amountIn.subtractOrZero(deduction))

            if deduction > 0, operation.amountIn > 0, operation.label == .swap {
                deduction = deduction * operation.amountOut / operation.amountIn
            }

            if let commission,
               index == commission.chargingOperationIndex,
               operation.assetOut.chainAssetId == commission.asset {
                deduction += commission.amount
            }

            amountsOut.append(operation.amountOut.subtractOrZero(deduction))
        }

        netAmountsIn = amountsIn
        netAmountsOut = amountsOut
    }

    func netAmountIn(at index: Int) -> Balance {
        netAmountsIn.indices.contains(index) ? netAmountsIn[index] : 0
    }

    func netAmountOut(at index: Int) -> Balance {
        netAmountsOut.indices.contains(index) ? netAmountsOut[index] : 0
    }

    var netFinalAmountOut: Balance {
        netAmountsOut.last ?? 0
    }
}
