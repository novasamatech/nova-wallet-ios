import CommonWallet
import RobinHood

protocol RemoteHistoryTransactionsProviderProtocol {
    func fetch(by filter: WalletHistoryFilter, count: Int) -> CompoundOperationWrapper<[TransactionHistoryItem]>?
    func fetchNext(by filter: WalletHistoryFilter, count: Int) -> CompoundOperationWrapper<[TransactionHistoryItem]>?
}

final class TransactionHistoryStreamableSource {
    let historyFacade: AssetHistoryFactoryFacadeProtocol
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let address: AccountAddress
    let chainAsset: ChainAsset
    let fetchCount: Int
    let operationQueue: OperationQueue

    private var pagination: Pagination?

    init(
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        address: AccountAddress,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<TransactionHistoryItem>,
        fetchCount: Int,
        operationQueue: OperationQueue
    ) {
        self.historyFacade = historyFacade
        self.address = address
        self.chainAsset = chainAsset
        self.repository = repository
        self.fetchCount = fetchCount
        self.operationQueue = operationQueue
    }

    private func createRemoteAssetHistory(
        filter: WalletHistoryFilter,
        count: Int
    ) -> CompoundOperationWrapper<[TransactionHistoryItem]>? {
        guard let pagination = pagination else {
            return CompoundOperationWrapper<[TransactionHistoryItem]>.createWithResult([])
        }
        guard let remoteFactory = historyFacade.createOperationFactory(for: chainAsset, filter: filter) else {
            return nil
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
                count: count,
                context: result.context
            )
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
        let remoteFactory = historyFacade.createOperationFactory(for: chainAsset, filter: .all)

        var dependencies: [Operation] = []
        let remoteOperation: BaseOperation<WalletRemoteHistoryData>?

        if let remoteHistoryWrapper = remoteFactory?.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        ) {
            remoteOperation = remoteHistoryWrapper.targetOperation
            dependencies.append(contentsOf: remoteHistoryWrapper.allOperations)
        } else {
            remoteOperation = nil
        }

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        dependencies.append(localFetchOperation)

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteOperation,
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
        utilityAsset _: AssetModel,
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
                    chainAsset: chainAsset
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
        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        if let queue = queue {
            queue.async {
                closure(result)
            }
        } else {
            closure(result)
        }
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

extension TransactionHistoryStreamableSource: RemoteHistoryTransactionsProviderProtocol {
    func fetchNext(by filter: WalletHistoryFilter, count: Int) -> CompoundOperationWrapper<[TransactionHistoryItem]>? {
        createRemoteAssetHistory(filter: filter, count: count)
    }

    func fetch(by filter: WalletHistoryFilter, count: Int) -> CompoundOperationWrapper<[TransactionHistoryItem]>? {
        pagination = .init(count: count)
        return createRemoteAssetHistory(filter: filter, count: count)
    }
}
