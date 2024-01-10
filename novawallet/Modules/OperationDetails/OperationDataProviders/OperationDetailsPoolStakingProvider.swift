import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class OperationDetailsPoolStakingProvider: OperationDetailsBaseProvider, AnyCancellableCleaning {
    let poolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    private var selectedPool: NominationPools.SelectedPool?

    private var cancellableCall: CancellableCall?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        transaction: TransactionHistoryItem,
        poolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.poolsOperationFactory = poolsOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue

        super.init(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            transaction: transaction
        )
    }

    deinit {
        clear(cancellable: &cancellableCall)
    }

    private func reportProgress(
        for model: OperationPoolRewardOrSlashModel,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        selectedPool = model.pool

        guard let accountAddress = accountAddress else {
            progressClosure(.poolReward(model))
            return
        }

        let isReward = transaction.type(
            for: accountAddress,
            chainAssetId: chainAsset.chainAssetId
        ) == .poolReward

        if isReward {
            progressClosure(.poolReward(model))
        } else {
            progressClosure(.poolSlash(model))
        }
    }

    private func getEventId(from context: HistoryPoolRewardContext?) -> String? {
        guard let eventId = context?.eventId else {
            return nil
        }
        return !eventId.isEmpty ? eventId : nil
    }

    private func fetchPool(
        for poolId: NominationPools.PoolId,
        waitingModel: OperationPoolRewardOrSlashModel,
        completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        clear(cancellable: &cancellableCall)

        let bondedPoolWrapper = poolsOperationFactory.createBondedAccountsWrapper(
            for: { [poolId] },
            runtimeService: runtimeService
        )
        let metadataWrapper = poolsOperationFactory.createMetadataWrapper(
            for: { [poolId] },
            connection: connection,
            runtimeService: runtimeService
        )
        let mergeOperation = ClosureOperation<OperationPoolRewardOrSlashModel> {
            let bondedPools = try bondedPoolWrapper.targetOperation.extractNoCancellableResultData()
            let metadataResult = try metadataWrapper.targetOperation.extractNoCancellableResultData()
            guard let bondedAccountId = bondedPools[poolId] else {
                return waitingModel
            }

            let metadata = metadataResult.first?.value

            let pool = NominationPools.SelectedPool(
                poolId: poolId,
                bondedAccountId: bondedAccountId,
                metadata: metadata,
                maxApy: nil
            )

            return waitingModel.byReplacingPool(pool)
        }

        mergeOperation.addDependency(bondedPoolWrapper.targetOperation)
        mergeOperation.addDependency(metadataWrapper.targetOperation)

        let dependencies = bondedPoolWrapper.allOperations + metadataWrapper.allOperations

        let wrapper = CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)

        mergeOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.cancellableCall === wrapper else {
                    return
                }

                self?.cancellableCall = nil

                do {
                    let model = try mergeOperation.extractNoCancellableResultData()
                    self?.reportProgress(for: model, progressClosure: completion)
                } catch {
                    completion(nil)
                }
            }
        }

        cancellableCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension OperationDetailsPoolStakingProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith _: BigUInt?,
        calculatorFactory: PriceHistoryCalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let optContext = try? transaction.call.map {
            try JSONDecoder().decode(HistoryPoolRewardContext.self, from: $0)
        }

        let priceCalculator = calculatorFactory.createPriceCalculator(for: chainAsset.asset.priceId)
        let eventId = getEventId(from: optContext) ?? transaction.txHash
        let amount = transaction.amountInPlankIntOrZero
        let priceData = priceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        let model = OperationPoolRewardOrSlashModel(
            eventId: eventId,
            amount: amount,
            priceData: priceData,
            pool: nil
        )

        if let selectedPool = selectedPool {
            reportProgress(for: model.byReplacingPool(selectedPool), progressClosure: progressClosure)
        } else if let poolId = optContext?.poolId {
            // send partial model to display while loading pool's metadata
            reportProgress(for: model, progressClosure: progressClosure)

            fetchPool(for: poolId, waitingModel: model, completion: progressClosure)
        } else {
            reportProgress(for: model, progressClosure: progressClosure)
        }
    }
}
