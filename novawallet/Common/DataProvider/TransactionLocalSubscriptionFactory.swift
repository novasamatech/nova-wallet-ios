import Foundation
import RobinHood

protocol TransactionLocalSubscriptionFactoryProtocol {
    func getTransactionsProviderById(
        _ txId: String,
        chainId: ChainModel.Id
    ) -> StreamableProvider<TransactionHistoryItem>

    func getUtilityAssetTransactionsProvider(
        for source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> StreamableProvider<TransactionHistoryItem>

    func getCustomAssetTransactionsProvider(
        for source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> StreamableProvider<TransactionHistoryItem>
}

final class TransactionLocalSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?
    let operationQueue: OperationQueue

    private(set) var providerStore: [String: WeakWrapper] = [:]

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func runStoreCleaner() {
        providerStore = providerStore.filter { $0.value.target != nil }
    }

    private func createKey(from txId: String, chainId: ChainModel.Id) -> String {
        chainId + txId
    }

    private func createKey(
        from source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> String {
        let key = String(source.rawValue) + chainAssetId.chainId + String(chainAssetId.assetId) + address

        if let filter = filter {
            return key + String(filter.rawValue)
        } else {
            return key
        }
    }

    func getProvider(
        for txId: String,
        chainId: ChainModel.Id
    ) -> StreamableProvider<TransactionHistoryItem>? {
        let key = createKey(from: txId, chainId: chainId)
        return providerStore[key]?.target as? StreamableProvider<TransactionHistoryItem>
    }

    func storeProvider(
        _ provider: StreamableProvider<TransactionHistoryItem>,
        txId: String,
        chainId: ChainModel.Id
    ) {
        let key = createKey(from: txId, chainId: chainId)
        providerStore[key] = WeakWrapper(target: provider)
    }

    func getProvider(
        for source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> StreamableProvider<TransactionHistoryItem>? {
        let key = createKey(from: source, address: address, chainAssetId: chainAssetId, filter: filter)
        return providerStore[key]?.target as? StreamableProvider<TransactionHistoryItem>
    }

    func storeProvider(
        _ provider: StreamableProvider<TransactionHistoryItem>,
        source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) {
        let key = createKey(from: source, address: address, chainAssetId: chainAssetId, filter: filter)
        providerStore[key] = WeakWrapper(target: provider)
    }

    func createTransactionsProvider(
        for modelFilter: NSPredicate,
        entityFilter: @escaping (CDTransactionItem) -> Bool
    ) -> StreamableProvider<TransactionHistoryItem> {
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem>
            = storageFacade.createRepository(filter: modelFilter)

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: entityFilter
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<TransactionHistoryItem>()

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

extension TransactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol {
    func getTransactionsProviderById(
        _ txId: String,
        chainId: ChainModel.Id
    ) -> StreamableProvider<TransactionHistoryItem> {
        runStoreCleaner()

        if let provider = getProvider(for: txId, chainId: chainId) {
            return provider
        }

        let provider = createTransactionsProvider(
            for: NSPredicate.filterTransactionsBy(transactionId: txId),
            entityFilter: { entity in
                entity.chainId == chainId && entity.identifier == txId
            }
        )

        storeProvider(provider, txId: txId, chainId: chainId)

        return provider
    }

    func getUtilityAssetTransactionsProvider(
        for source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> StreamableProvider<TransactionHistoryItem> {
        runStoreCleaner()

        if let provider = getProvider(for: source, address: address, chainAssetId: chainAssetId, filter: filter) {
            return provider
        }

        let predicate = NSPredicate.filterUtilityAssetTransactionsBy(
            address: address,
            chainId: chainAssetId.chainId,
            utilityAssetId: chainAssetId.assetId,
            source: source,
            filter: filter
        )

        let provider = createTransactionsProvider(
            for: predicate,
            entityFilter: { entity in
                predicate.evaluate(with: entity)
            }
        )

        storeProvider(provider, source: source, address: address, chainAssetId: chainAssetId, filter: filter)

        return provider
    }

    func getCustomAssetTransactionsProvider(
        for source: TransactionHistoryItemSource,
        address: AccountAddress,
        chainAssetId: ChainAssetId,
        filter: WalletHistoryFilter?
    ) -> StreamableProvider<TransactionHistoryItem> {
        runStoreCleaner()

        if let provider = getProvider(for: source, address: address, chainAssetId: chainAssetId, filter: filter) {
            return provider
        }

        let predicate = NSPredicate.filterTransactionsBy(
            address: address,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId,
            source: source,
            filter: filter
        )

        let provider = createTransactionsProvider(
            for: predicate,
            entityFilter: { entity in
                predicate.evaluate(with: entity)
            }
        )

        storeProvider(provider, source: source, address: address, chainAssetId: chainAssetId, filter: filter)

        return provider
    }
}
