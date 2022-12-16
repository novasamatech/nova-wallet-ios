import CommonWallet
import RobinHood

final class TransactionHistoryStreamableSource {
    let remoteFactory: WalletRemoteHistoryFactoryProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let address: AccountAddress
    let chainAsset: ChainAsset
    let filter: WalletHistoryFilter
    let count: Int = 100
    let operationQueue: OperationQueue

    var pagination: Pagination?

    init(
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        address: AccountAddress,
        chainAsset: ChainAsset,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        filter: WalletHistoryFilter,
        operationQueue: OperationQueue
    ) {
        remoteFactory = historyFacade.createOperationFactory(for: chainAsset, filter: filter)!
        self.address = address
        self.chainAsset = chainAsset
        self.filter = filter
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    private func createRemoteAssetHistoryWithoutSave(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        filter _: WalletHistoryFilter,
        remoteFactory: WalletRemoteHistoryFactoryProtocol,
        repositoryFactory _: SubstrateRepositoryFactoryProtocol
    ) -> CompoundOperationWrapper<[TransactionHistoryItem]> {
        guard let pagination = pagination else {
            return CompoundOperationWrapper<[TransactionHistoryItem]>.createWithResult([])
        }
        let chain = chainAsset.chain
        let remoteAddress = (chain.isEthereumBased ? address.toEthereumAddressWithChecksum() : address) ?? address

        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        )

        let operation = ClosureOperation { [weak self] in
            let result = try remoteHistoryWrapper.targetOperation.extractNoCancellableResultData()
            let remoteTransactions = result.historyItems
            self?.pagination = .init(count: remoteTransactions.count, context: result.context)

            let transactions: [TransactionHistoryItem] = remoteTransactions.compactMap { item in
                if let etherscanItem = item as? EtherscanHistoryElement {
                    return etherscanItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
                } else if let subqueryItem = item as? SubqueryHistoryElement {
                    return subqueryItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
                } else {
                    return nil
                }
            }

            return transactions
        }

        operation.addDependency(remoteHistoryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: remoteHistoryWrapper.allOperations
        )
    }

    private func createRemoteAssetHistory(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        filter: WalletHistoryFilter,
        remoteFactory: WalletRemoteHistoryFactoryProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol
    ) -> CompoundOperationWrapper<[TransactionHistoryItem]> {
        let pagination = pagination ?? Pagination(count: count, context: nil)

        let chain = chainAsset.chain
        let remoteAddress = (chain.isEthereumBased ? address.toEthereumAddressWithChecksum() : address) ?? address
        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        )

        var dependencies = remoteHistoryWrapper.allOperations
        let txStorage = createLocalRepository(
            for: address,
            chainAsset: chainAsset,
            repositoryFactory: repositoryFactory
        )
        let wrapper = createLocalFetchWrapper(for: filter, txStorage: txStorage)
        wrapper.addDependency(wrapper: remoteHistoryWrapper)
        dependencies.append(contentsOf: wrapper.allOperations)
        let localFetchOperation = wrapper.targetOperation

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            chainAsset: chainAsset,
            utilityAsset: chainAsset.asset,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }
        dependencies.append(mergeOperation)

        let saveOperation = txStorage.saveOperation({
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return mergeResult.historyItems
        }, {
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return mergeResult.identifiersToRemove
        })

        dependencies.append(saveOperation)
        saveOperation.addDependency(mergeOperation)

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<WalletRemoteHistoryData>
    ) -> BaseOperation<[TransactionHistoryItem]> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()

            // we still need to return local operations if remote failed
            let optNewHistoryResult = try? remoteOperation.extractNoCancellableResultData()
            let newHistoryContext = optNewHistoryResult?.context

            return mergeResult.historyItems
        }
    }

    private func createLocalRepository(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        repositoryFactory: SubstrateRepositoryFactoryProtocol
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let utilityAsset = chainAsset.chain.utilityAssets().first
        let source: TransactionHistoryItemSource = chainAsset.asset.isEvm ? .evm : .substrate

        if let utilityAssetId = utilityAsset?.assetId, utilityAssetId == chainAsset.asset.assetId {
            return repositoryFactory.createUtilityAssetTxRepository(
                for: address,
                chainId: chainAsset.chain.chainId,
                assetId: utilityAssetId,
                source: source
            )
        } else {
            return repositoryFactory.createCustomAssetTxRepository(
                for: address,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId,
                source: source
            )
        }
    }

    private func createLocalFetchWrapper(
        for filter: WalletHistoryFilter,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) -> CompoundOperationWrapper<[TransactionHistoryItem]> {
        let fetchOperation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())

        let filterOperation = ClosureOperation<[TransactionHistoryItem]> {
            let items = try fetchOperation.extractNoCancellableResultData()

            return items.filter { item in
                if item.callPath.isSubstrateOrEvmTransfer, !filter.contains(.transfers) {
                    return false
                } else if !item.callPath.isSubstrateOrEvmTransfer, !filter.contains(.extrinsics) {
                    return false
                } else {
                    return true
                }
            }
        }

        filterOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: filterOperation, dependencies: [fetchOperation])
    }

    func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation { [weak self] in
            let result = try remoteOperation?.extractNoCancellableResultData()
            let remoteTransactions = result?.historyItems ?? []
            self?.pagination = .init(
                count: remoteTransactions.count,
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
                    if let etherscanItem = item as? EtherscanHistoryElement {
                        return etherscanItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
                    } else if let subqueryItem = item as? SubqueryHistoryElement {
                        return subqueryItem.createTransactionItem(chainAssetId: chainAsset.chainAssetId)
                    } else {
                        return nil
                    }
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
        let operation = createRemoteAssetHistoryWithoutSave(
            for: address,
            chainAsset: chainAsset,
            filter: filter,
            remoteFactory: remoteFactory,
            repositoryFactory: repositoryFactory
        )

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
        let operation = createRemoteAssetHistory(
            for: address,
            chainAsset: chainAsset,
            filter: filter,
            remoteFactory: remoteFactory,
            repositoryFactory: repositoryFactory
        )

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
}
