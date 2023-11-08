import Foundation
import BigInt

final class OperationDetailsExtrinsicProvider: OperationDetailsBaseProvider {}

extension OperationDetailsExtrinsicProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: CalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            progressClosure(nil)
            return
        }

        let feePriceCalculator = calculatorFactory.createPriceCalculator(for: chain.utilityAsset()?.priceId)
        let fee = newFee ?? transaction.feeInPlankIntOrZero
        let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        let currentDisplayAddress = DisplayAddress(
            address: accountAddress,
            username: selectedAccount.chainAccount.name
        )

        let model = OperationExtrinsicModel(
            txHash: transaction.txHash,
            call: transaction.callPath.callName,
            module: transaction.callPath.moduleName,
            sender: currentDisplayAddress,
            fee: fee,
            feePriceData: feePriceData
        )

        progressClosure(.extrinsic(model))
    }
}
