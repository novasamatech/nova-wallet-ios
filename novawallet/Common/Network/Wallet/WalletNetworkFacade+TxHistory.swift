import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto

extension WalletNetworkFacade {
    func createAssetHistory(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        pagination: Pagination,
        filter: WalletHistoryFilter
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let maybeRemoteHistoryFactory = AssetHistoryFacade().createOperationFactory(
            for: chainAsset,
            filter: filter
        )

        if let remoteFactory = maybeRemoteHistoryFactory {
            return createRemoteAssetHistory(
                for: address,
                chainAsset: chainAsset,
                pagination: pagination,
                filter: filter,
                remoteFactory: remoteFactory
            )
        } else {
            return createLocalAssetHistory(
                for: address,
                chainAsset: chainAsset,
                pagination: pagination,
                filter: filter
            )
        }
    }

    private func createLocalRepository(
        for address: AccountAddress,
        chainAsset: ChainAsset
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let utilityAsset = chainAsset.chain.utilityAssets().first
        let source = TransactionHistoryItemSource(assetTypeString: chainAsset.asset.type)

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

    func createRemoteAssetHistory(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        pagination: Pagination,
        filter: WalletHistoryFilter,
        remoteFactory: WalletRemoteHistoryFactoryProtocol
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard !remoteFactory.isComplete(pagination: pagination) else {
            return createEmptyHistoryResponseOperation()
        }

        let chain = chainAsset.chain

        let remoteAddress: AccountAddress

        if chain.isEthereumBased {
            remoteAddress = address.toEthereumAddressWithChecksum() ?? address
        } else {
            remoteAddress = address
        }

        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(for: remoteAddress, pagination: pagination)

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        let txStorage = createLocalRepository(for: address, chainAsset: chainAsset)

        if pagination.context == nil {
            let wrapper = createLocalFetchWrapper(for: filter, txStorage: txStorage)

            wrapper.addDependency(wrapper: remoteHistoryWrapper)

            dependencies.append(contentsOf: wrapper.allOperations)

            localFetchOperation = wrapper.targetOperation
        } else {
            localFetchOperation = nil
        }

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            chainAsset: chainAsset,
            utilityAsset: chainAsset.asset,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if pagination.context == nil {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation,
            previousContext: pagination.context
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createLocalAssetHistory(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        pagination: Pagination,
        filter: WalletHistoryFilter
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            pagination.context == nil else {
            return createEmptyHistoryResponseOperation()
        }

        let txStorage = createLocalRepository(for: address, chainAsset: chainAsset)

        let wrapper = createLocalFetchWrapper(for: filter, txStorage: txStorage)

        let mapOperation = ClosureOperation<AssetTransactionPageData?> {
            let transactions = try wrapper.targetOperation.extractNoCancellableResultData()

            let assetTransactions = transactions.map { transaction in
                AssetTransactionData.createTransaction(
                    from: transaction,
                    address: address,
                    chainAsset: chainAsset,
                    utilityAsset: utilityAsset
                )
            }

            return AssetTransactionPageData(
                transactions: assetTransactions,
                context: nil
            )
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = wrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        chainAsset: ChainAsset,
        utilityAsset: AssetModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyItems ?? []

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
               !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    chainAsset: chainAsset,
                    utilityAsset: utilityAsset
                )

                return manager.merge(remoteItems: remoteTransactions, localItems: localTransactions)
            } else {
                let transactions: [AssetTransactionData] = remoteTransactions.map { item in
                    item.createTransactionForAddress(
                        address,
                        assetId: chainAsset.chainAssetId.walletId,
                        chainAsset: chainAsset,
                        utilityAsset: utilityAsset
                    )
                }

                return TransactionHistoryMergeResult(historyItems: transactions, identifiersToRemove: [])
            }
        }
    }

    func createHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<WalletRemoteHistoryData>,
        previousContext: PaginationContext?
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()

            // we still need to return local operations if remote failed
            let optNewHistoryResult = try? remoteOperation.extractNoCancellableResultData()
            let newHistoryContext = optNewHistoryResult?.context ?? previousContext

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: newHistoryContext
            )
        }
    }

    func createEmptyHistoryResponseOperation() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let pageData = AssetTransactionPageData(
            transactions: [],
            context: nil
        )

        let operation = BaseOperation<AssetTransactionPageData?>()
        operation.result = .success(pageData)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createLocalFetchWrapper(
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
}
