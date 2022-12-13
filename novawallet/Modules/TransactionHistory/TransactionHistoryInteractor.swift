import UIKit
import SoraUI
import RobinHood
import CommonWallet

final class TransactionHistoryInteractor {
    weak var presenter: TransactionHistoryInteractorOutputProtocol!
    let historyFacade: AssetHistoryFactoryFacadeProtocol = AssetHistoryFacade()
    let repositoryFactory: SubstrateRepositoryFactoryProtocol = SubstrateRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
    let dataProvider: SingleValueProvider<AssetTransactionPageData>

    private func createAssetHistory(
        for address: AccountAddress,
        chainAsset: ChainAsset,
        pagination: Pagination,
        filter: WalletHistoryFilter
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let maybeRemoteHistoryFactory = historyFacade.createOperationFactory(
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

    private func createLocalAssetHistory(
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

    private func createLocalRepository(
        for address: AccountAddress,
        chainAsset: ChainAsset
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

    private func createEmptyHistoryResponseOperation() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let pageData = AssetTransactionPageData(
            transactions: [],
            context: nil
        )

        let operation = BaseOperation<AssetTransactionPageData?>()
        operation.result = .success(pageData)
        return CompoundOperationWrapper(targetOperation: operation)
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

    private func createRemoteAssetHistory(
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
        let remoteAddress = (chain.isEthereumBased ? address.toEthereumAddressWithChecksum() : address) ?? address
        let remoteHistoryWrapper = remoteFactory.createOperationWrapper(
            for: remoteAddress,
            pagination: pagination
        )

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

    private func createHistoryMapOperation(
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
    
    func fetchTransactionHistoryOperation(
        _ request: WalletHistoryRequest,
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let mayBeUserAssets = request.assets?.filter { $0 != totalPriceId }

        // The history only works for asset detals now
        guard let userAssets = mayBeUserAssets,
              userAssets.count == 1,
              let walletAssetId = userAssets.first,
              let chainAssetId = ChainAssetId(walletId: walletAssetId),
              let chain = chains[chainAssetId.chainId],
              let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
              let utilityAsset = chain.utilityAssets().first,
              let address = metaAccount.fetch(for: chain.accountRequest())?.toAddress()
        else {
            return createEmptyHistoryResponseOperation()
        }

        let filter = WalletHistoryFilter(string: request.filter)

        let assetFilter: WalletHistoryFilter

        if asset.assetId != utilityAsset.assetId {
            assetFilter = filter.subtracting([.rewardsAndSlashes, .extrinsics])
        } else {
            assetFilter = filter
        }

        return createAssetHistory(
            for: address,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            pagination: pagination,
            filter: assetFilter
        )
    }
    
    func fetchTransactionHistory(for filter: WalletHistoryRequest,
                                 pagination: Pagination,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping TransactionHistoryBlock)
        -> CancellableCall {

        let operationWrapper = operationFactory.fetchTransactionHistoryOperation(filter,
                                                                                 pagination: pagination)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations,
                                     waitUntilFinished: false)

        return operationWrapper
    }
    
}

extension TransactionHistoryInteractor: TransactionHistoryInteractorInputProtocol {
    
    func setup() {
        setupDataProvider()
    }
    
    func refresh() {
        
    }
    
    func loadNext(for filter: WalletHistoryRequest,
                  pagination: Pagination) {
        fetchTransactionHistory(for: filter,
                                pagination: pagination,
                                runCompletionIn: .main) { [weak self] (optionalResult) in
            if let result = optionalResult {
                switch result {
                case .success(let pageData):
                    let loadedData = pageData ??
                    AssetTransactionPageData(transactions: [])
                    self?.presenter.handle
                    
                    handleNext(transactionData: loadedData,
                                     for: pagination)
                case .failure(let error):
                    self?.handleNext(error: error, for: pagination)
                }
            }
        }
    }
    
}

extension TransactionHistoryInteractor {
    private func setupDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<AssetTransactionPageData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    self?.handleDataProvider(transactionData: item)
                default:
                    break
                }
            } else {
                self?.handleDataProvider(transactionData: nil)
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: failBlock,
                                 options: options)
    }
    
    private func clearDataProvider() {
        dataProvider.removeObserver(self)
    }

}
