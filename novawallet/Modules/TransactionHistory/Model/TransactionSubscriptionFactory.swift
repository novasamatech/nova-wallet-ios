import RobinHood
import CommonWallet

final class TransactionSubscriptionProvider {
    let remote: StreamableProvider<TransactionHistoryItem>
    let local: StreamableProvider<TransactionHistoryItem>

    init(
        local: StreamableProvider<TransactionHistoryItem>,
        remote: StreamableProvider<TransactionHistoryItem>
    ) {
        self.local = local
        self.remote = remote
    }
}

protocol TransactionSubscriptionFactoryProtocol {
    func getTransactionsProvider(
        address: String,
        chainAsset: ChainAsset,
        historyFilter: WalletHistoryFilter
    ) throws -> TransactionSubscriptionProvider
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
}

extension TransactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol {
    func getTransactionsProvider(
        address: String,
        chainAsset: ChainAsset,
        historyFilter: WalletHistoryFilter
    ) throws -> TransactionSubscriptionProvider {
        let chainId = chainAsset.chainAssetId.chainId
        let assetId = chainAsset.chainAssetId.assetId
        let localCacheKey = "transactions-\(chainId)-\(assetId)-\(address)-\(historyFilter.rawValue)-local"
        let remoteCacheKey = "transactions-\(chainId)-\(assetId)-\(address)-\(historyFilter.rawValue)-remote"

        if let localProvider = getProvider(for: localCacheKey) as? StreamableProvider<TransactionHistoryItem>,
           let remoteProvider = getProvider(for: remoteCacheKey) as? StreamableProvider<TransactionHistoryItem> {
            return .init(
                local: localProvider,
                remote: remoteProvider
            )
        }

        let sourceFilter: TransactionHistoryItemSource = chainAsset.asset.isEvm ? .evm : .substrate
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

        let coreDataRepository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> = storageFacade.createRepository(filter: filter)
        let repository = AnyDataProviderRepository(coreDataRepository)

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(coreDataRepository.dataMapper),
            predicate: { [historyFilter] entity in
                entity.chainId == chainId &&
                    entity.assetId == assetId &&
                    historyFilter.isFit(moduleName: entity.moduleName, callName: entity.callName)
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = TransactionHistoryStreamableSource(
            historyFacade: historyFacade,
            address: address,
            chainAsset: chainAsset,
            repository: repository,
            filter: historyFilter,
            fetchCount: fetchCount,
            operationQueue: operationQueue
        )

        let sharedSource = AnyStreamableSource(source)

        let localProvider = StreamableProvider(
            source: sharedSource,
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let emptyRepository = EmptyDataProviderRepository<TransactionHistoryItem>()

        let remoteProvider = StreamableProvider(
            source: sharedSource,
            repository: AnyDataProviderRepository(emptyRepository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        saveProvider(localProvider, for: localCacheKey)
        saveProvider(remoteProvider, for: remoteCacheKey)

        return .init(local: localProvider, remote: remoteProvider)
    }
}
