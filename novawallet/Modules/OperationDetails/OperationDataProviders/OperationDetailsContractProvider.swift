import Foundation
import BigInt

final class OperationDetailsContractProvider: OperationDetailsBaseProvider {}

extension OperationDetailsContractProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: PriceHistoryCalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let feePriceCalculator = calculatorFactory.createPriceCalculator(for: chainAsset.chain.utilityAsset()?.priceId)

        let fee: BigUInt = newFee ?? transaction.feeInPlankIntOrZero
        let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        guard let currentAccountAddress = accountAddress else {
            progressClosure(nil)
            return
        }

        let currentDisplayAddress = DisplayAddress(
            address: currentAccountAddress,
            username: selectedAccount.chainAccount.name
        )

        let contractAddress = transaction.receiver.flatMap { try? Data(hex: $0).toAddress(using: chain.chainFormat) }
        let contractDisplayAddress = DisplayAddress(address: contractAddress ?? "", username: "")

        let model = OperationContractCallModel(
            txHash: transaction.txHash,
            fee: fee,
            feePriceData: feePriceData,
            sender: currentDisplayAddress,
            contract: contractDisplayAddress,
            functionName: transaction.evmContractFunctionName
        )

        progressClosure(.contract(model))
    }
}
