import CommonWallet
import RobinHood

final class TransactionHistoryStreamableSource {
    let remoteFactory: WalletRemoteHistoryFactoryProtocol
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let address: AccountAddress
    let chainAsset: ChainAsset
    let filter: WalletHistoryFilter
    let fetchCount: Int
    let operationQueue: OperationQueue

    private var pagination: Pagination?

    init(
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        address: AccountAddress,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        filter: WalletHistoryFilter,
        fetchCount: Int,
        operationQueue: OperationQueue
    ) {
        remoteFactory = historyFacade.createOperationFactory(for: chainAsset, filter: filter)!
        self.address = address
        self.chainAsset = chainAsset
        self.filter = filter
        self.repository = repository
        self.fetchCount = fetchCount
        self.operationQueue = operationQueue
    }

    private func createRemoteAssetHistory() -> CompoundOperationWrapper<[TransactionHistoryItem]> {
        guard let pagination = pagination else {
            return CompoundOperationWrapper<[TransactionHistoryItem]>.createWithResult([])
        }
        let chain = chainAsset.chain
        let remoteAddress = (chain.isEthereumBased ? address.toEthereumAddressWithChecksum() : address) ?? address

        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        )

        let operation = ClosureOperation {
            let result = try remoteHistoryWrapper.targetOperation.extractNoCancellableResultData()
            let remoteTransactions = result.historyItems
            self.pagination = .init(
                count: self.fetchCount,
                context: result.context
            )
            let filter = self.filter

            let transactions: [TransactionHistoryItem] = remoteTransactions.compactMap { item in
                item.createTransaction(chainAsset: self.chainAsset)
            }.filter { item in
                filter.isFit(callPath: item.callPath)
            }

            return transactions
        }

        operation.addDependency(remoteHistoryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: remoteHistoryWrapper.allOperations
        )
    }

    private func createAssetHistory() -> CompoundOperationWrapper<Void> {
        let pagination = pagination ?? Pagination(count: fetchCount, context: nil)

        let chain = chainAsset.chain
        let remoteAddress = (chain.isEthereumBased ? address.toEthereumAddressWithChecksum() : address) ?? address
        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        )

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        dependencies.append(localFetchOperation)

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            chainAsset: chainAsset,
            utilityAsset: chainAsset.asset,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }
        dependencies.append(mergeOperation)

        let saveOperation = repository.saveOperation({
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return mergeResult.historyItems
        }, {
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return mergeResult.identifiersToRemove
        })

        saveOperation.addDependency(mergeOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation, dependencies: dependencies)
    }

    func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let result = try remoteOperation?.extractNoCancellableResultData()
            let remoteTransactions = result?.historyItems ?? []

            self.pagination = .init(
                count: self.fetchCount,
                context: result?.context
            )

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
               !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    chainAsset: chainAsset,
                    utilityAsset: utilityAsset
                )

                return manager.merge(remoteItems: remoteTransactions, localItems: localTransactions)
            } else {
                let transactions: [TransactionHistoryItem] = remoteTransactions.compactMap { item in
                    item.createTransaction(chainAsset: chainAsset)
                }

                return TransactionHistoryMergeResult(historyItems: transactions, identifiersToRemove: [])
            }
        }
    }
}

extension TransactionHistoryStreamableSource: StreamableSourceProtocol {
    typealias Model = TransactionHistoryItem

    func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        let operation = createRemoteAssetHistory()

        let queue = queue ?? .global()

        operation.targetOperation.completionBlock = {
            do {
                let count = try operation.targetOperation.extractNoCancellableResultData().count

                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.success(count))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.failure(error))
                }
            }
        }

        operationQueue.addOperations(operation.allOperations, waitUntilFinished: false)
    }

    func refresh(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        let operation = createAssetHistory()

        operation.targetOperation.completionBlock = {
            do {
                try operation.targetOperation.extractNoCancellableResultData()

                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.success(1))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    commitNotificationBlock?(.failure(error))
                }
            }
        }

        operationQueue.addOperations(operation.allOperations, waitUntilFinished: false)
    }
}
