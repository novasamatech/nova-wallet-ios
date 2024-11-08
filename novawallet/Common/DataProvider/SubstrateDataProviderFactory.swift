import Foundation
import Operation_iOS

protocol SubstrateDataProviderFactoryProtocol {
    func createStashItemProvider(for address: String, chainId: ChainModel.Id) -> StreamableProvider<StashItem>
    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem>
}

final class SubstrateDataProviderFactory: SubstrateDataProviderFactoryProtocol {
    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(
        facade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createStashItemProvider(for address: String, chainId: ChainModel.Id) -> StreamableProvider<StashItem> {
        let mapper = StashItemMapper()

        let repository = SubstrateRepositoryFactory(storageFacade: facade)
            .createStashItemRepository(for: address, chainId: chainId)

        let observable = CoreDataContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { ($0.stash == address || $0.controller == address) && $0.chainId == chainId }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<StashItem>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }

    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
        let filter = NSPredicate.filterStorageItemsBy(identifier: key)
        let mapper = ChainStorageItemMapper()
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            facade.createRepository(filter: filter, sortDescriptors: [], mapper: AnyCoreDataMapper(mapper))
        let source = EmptyStreamableSource<ChainStorageItem>()
        let observable = CoreDataContextObservable(
            service: facade.databaseService,
            mapper: AnyCoreDataMapper(storage.dataMapper),
            predicate: { $0.identifier == key }
        )

        observable.start { error in
            if let error = error {
                self.logger?.error("Can't start storage observing: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(storage),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }
}
