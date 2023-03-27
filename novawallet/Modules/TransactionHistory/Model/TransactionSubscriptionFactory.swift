import RobinHood
import CommonWallet

protocol TransactionSubscriptionFactoryProtocol {
    func getTransactionsProvider(
        address: String,
        chainAsset: ChainAsset
    ) throws -> StreamableProvider<TransactionHistoryItem>

    func getRemoteTransactionsProvider(
        address: String,
        chainAsset: ChainAsset
    ) throws -> RemoteHistoryTransactionsProviderProtocol
}

final class TransactionSubscriptionFactory: BaseLocalSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?
    let operationQueue: OperationQueue
    let historyFacade: AssetHistoryFactoryFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let fetchCount: Int

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        fetchCount: Int,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
        self.historyFacade = historyFacade
        self.repositoryFactory = repositoryFactory
        self.fetchCount = fetchCount
    }

    private func getSourceKey(
        address: String,
        chainAssetId: ChainAssetId
    ) -> String {
        "source-\(chainAssetId.chainId)-\(chainAssetId.assetId)-\(address)"
    }

    private func getLocalProviderKey(
        address: String,
        chainAssetId: ChainAssetId
    ) -> String {
        "transactions-\(chainAssetId.chainId)-\(chainAssetId.assetId)-\(address)"
    }

    private func createRepository(
        address: String,
        chainAsset: ChainAsset
    ) -> CoreDataRepository<TransactionHistoryItem, CDTransactionItem> {
        let chainId = chainAsset.chainAssetId.chainId
        let assetId = chainAsset.chainAssetId.assetId
        let sourceFilter: TransactionHistoryItemSource = .init(assetTypeString: chainAsset.asset.type)
        var filter: NSPredicate
        if let utilityAssetId = chainAsset.chain.utilityAsset()?.assetId,
           utilityAssetId == chainAsset.asset.assetId {
            filter = .filterUtilityAssetTransactionsBy(
                address: address,
                chainId: chainId,
                utilityAssetId: utilityAssetId,
                source: sourceFilter
            )
        } else {
            filter = .filterTransactionsBy(
                address: address,
                chainId: chainId,
                assetId: assetId,
                source: sourceFilter
            )
        }

        return storageFacade.createRepository(filter: filter)
    }
}

extension TransactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol {
    func getTransactionsProvider(
        address: String,
        chainAsset: ChainAsset
    ) throws -> StreamableProvider<TransactionHistoryItem> {
        let chainId = chainAsset.chainAssetId.chainId
        let assetId = chainAsset.chainAssetId.assetId
        let cacheKey = getLocalProviderKey(address: address, chainAssetId: chainAsset.chainAssetId)
        let sourceCacheKey = getSourceKey(address: address, chainAssetId: chainAsset.chainAssetId)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<TransactionHistoryItem> {
            return provider
        }
        let coreDataRepository = createRepository(
            address: address,
            chainAsset: chainAsset
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(coreDataRepository.dataMapper),
            predicate: { entity in
                entity.chainId == chainId &&
                    entity.assetId == assetId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let repository = AnyDataProviderRepository(coreDataRepository)

        let cachedSource = getProvider(for: sourceCacheKey) as? TransactionHistoryStreamableSource
        let source: TransactionHistoryStreamableSource
        if let cachedSource = getProvider(for: sourceCacheKey) as? TransactionHistoryStreamableSource {
            source = cachedSource
        } else {
            source = TransactionHistoryStreamableSource(
                historyFacade: historyFacade,
                address: address,
                chainAsset: chainAsset,
                repository: repository,
                fetchCount: fetchCount,
                operationQueue: operationQueue
            )
            saveProvider(source, for: sourceCacheKey)
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getRemoteTransactionsProvider(
        address: String,
        chainAsset: ChainAsset
    ) throws -> RemoteHistoryTransactionsProviderProtocol {
        let sourceCacheKey = getSourceKey(address: address, chainAssetId: chainAsset.chainAssetId)

        if let provider = getProvider(for: sourceCacheKey) as? TransactionHistoryStreamableSource {
            return provider
        }

        let repository = AnyDataProviderRepository(createRepository(
            address: address,
            chainAsset: chainAsset
        ))

        let source = TransactionHistoryStreamableSource(
            historyFacade: historyFacade,
            address: address,
            chainAsset: chainAsset,
            repository: repository,
            fetchCount: fetchCount,
            operationQueue: operationQueue
        )

        saveProvider(source, for: sourceCacheKey)

        return source
    }
}
