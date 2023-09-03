import SubstrateSdk
import BigInt
import RobinHood

protocol OperationDetailsDataFactoryProtocol {
    func extractOperationData(
        transaction: TransactionHistoryItem,
        newFee: BigUInt?,
        priceCalculator: TokenPriceCalculatorProtocol?,
        feePriceCalculator: TokenPriceCalculatorProtocol?
    ) -> CompoundOperationWrapper<OperationDetailsModel.OperationData?>
}

final class PoolRewardsOperationDetailsDataFactory: OperationDetailsDataFactoryProtocol {
    let poolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.poolsOperationFactory = poolsOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
    }

    func extractOperationData(
        transaction: TransactionHistoryItem,
        newFee: BigUInt?,
        priceCalculator: TokenPriceCalculatorProtocol?,
        feePriceCalculator: TokenPriceCalculatorProtocol?
    ) -> CompoundOperationWrapper<OperationDetailsModel.OperationData?> {
        guard let poolId = NominationPools.PoolId(transaction.sender) else {
            return CompoundOperationWrapper.createWithResult(nil)
        }
        let bondedPoolWrapper = poolsOperationFactory.createBondedAccountsWrapper(
            for: { [poolId] },
            runtimeService: runtimeService
        )
        let metadataWrapper = poolsOperationFactory.createMetadataWrapper(
            for: { [poolId] },
            connection: connection,
            runtimeService: runtimeService
        )
        let mergeOperation = ClosureOperation<OperationDetailsModel.OperationData?> {
            let bondedPools = try bondedPoolWrapper.targetOperation.extractNoCancellableResultData()
            let metadataResult = try metadataWrapper.targetOperation.extractNoCancellableResultData()
            guard let bondedAccountId = bondedPools[poolId] else {
                return nil
            }

            let metadata = metadataResult.first?.value
            let eventId = transaction.txHash
            let amount = transaction.amountInPlankIntOrZero
            let priceData = priceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
                PriceData.amount($0)
            }
            let fee = newFee ?? transaction.feeInPlankIntOrZero
            let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
                PriceData.amount($0)
            }

            let model = OperationPoolRewardModel(
                eventId: eventId,
                amount: amount,
                priceData: priceData,
                fee: fee,
                feePriceData: feePriceData,
                pool: NominationPools.SelectedPool(
                    poolId: poolId,
                    bondedAccountId: bondedAccountId,
                    metadata: metadata,
                    maxApy: nil
                )
            )

            return .poolReward(model)
        }

        let dependencies = bondedPoolWrapper.allOperations + metadataWrapper.allOperations
        dependencies.forEach(mergeOperation.addDependency)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
