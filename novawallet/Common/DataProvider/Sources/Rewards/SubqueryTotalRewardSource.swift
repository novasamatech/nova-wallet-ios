import Foundation
import RobinHood
import BigInt
import CommonWallet

final class SubqueryTotalRewardSource {
    typealias Model = TotalRewardItem

    let address: AccountAddress
    let assetPrecision: Int16
    let operationFactory: SubqueryRewardOperationFactoryProtocol

    init(
        address: AccountAddress,
        assetPrecision: Int16,
        operationFactory: SubqueryRewardOperationFactoryProtocol
    ) {
        self.address = address
        self.assetPrecision = assetPrecision
        self.operationFactory = operationFactory
    }

    private func createMapOperation(
        dependingOn fetchOperation: BaseOperation<BigUInt>,
        address: AccountAddress,
        precision: Int16
    ) -> BaseOperation<Model?> {
        ClosureOperation<Model?> {
            let rewardValue = try fetchOperation.extractNoCancellableResultData()
            let newRewardDecimal = Decimal.fromSubstrateAmount(rewardValue, precision: precision) ?? 0
            return TotalRewardItem(address: address, amount: AmountDecimal(value: newRewardDecimal))
        }
    }
}

extension SubqueryTotalRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let rewardOperation = operationFactory.createTotalRewardOperation(for: address)

        let mapOperation = createMapOperation(
            dependingOn: rewardOperation,
            address: address,
            precision: assetPrecision
        )

        mapOperation.addDependency(rewardOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [rewardOperation])
    }
}
