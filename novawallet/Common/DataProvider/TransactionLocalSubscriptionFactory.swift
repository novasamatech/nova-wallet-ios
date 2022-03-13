import Foundation
import RobinHood

protocol TransactionLocalSubscriptionFactoryProtocol {
    func getTransactionsProviderById(
        _ txId: String,
        chainId: ChainModel.Id
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

        let filter = NSPredicate.filterTransactionsBy(transactionId: txId)
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem>
            = storageFacade.createRepository(filter: filter)

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: { entity in
                entity.chainId == chainId &&
                    entity.identifier == txId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<TransactionHistoryItem>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        storeProvider(provider, txId: txId, chainId: chainId)

        return provider
    }
}
