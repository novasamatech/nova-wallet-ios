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

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        historyFacade: AssetHistoryFactoryFacadeProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
        self.historyFacade = historyFacade
        self.repositoryFactory = repositoryFactory
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
        let localCacheKey = "transactions-\(chainId)-\(assetId)-\(address)-local"
        let remoteCacheKey = "transactions-\(chainId)-\(assetId)-\(address)-remote"

        if let localProvider = getProvider(for: localCacheKey) as? StreamableProvider<TransactionHistoryItem>,
           let remoteProvider = getProvider(for: localCacheKey) as? StreamableProvider<TransactionHistoryItem> {
            return .init(
                local: localProvider,
                remote: remoteProvider
            )
        }

        let filter = NSPredicate.filterTransactionsBy(
            address: address,
            chainId: chainId,
            assetId: assetId,
            source: nil
        )

        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> = storageFacade.createRepository(filter: filter)

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: { entity in
                entity.chainId == chainId &&
                    (entity.sender == address || entity.receiver == address) &&
                    entity.assetId == assetId
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
            repositoryFactory: repositoryFactory,
            filter: historyFilter,
            operationQueue: operationQueue
        )

        let sharedSource = AnyStreamableSource(source)

        let localProvider = StreamableProvider(
            source: sharedSource,
            repository: AnyDataProviderRepository(repository),
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
