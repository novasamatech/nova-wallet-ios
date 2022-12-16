import RobinHood
import CommonWallet

protocol TransactionSubscriptionFactoryProtocol {
    func getTransactionsProvider(
        address: String,
        chainAsset: ChainAsset,
        historyFilter: WalletHistoryFilter
    ) throws -> StreamableProvider<TransactionHistoryItem>
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
    ) throws -> StreamableProvider<TransactionHistoryItem> {
        let chainId = chainAsset.chainAssetId.chainId
        let assetId = chainAsset.chainAssetId.assetId
        let cacheKey = "transactions-\(chainId)-\(assetId)-\(address)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<TransactionHistoryItem> {
            return provider
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

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
