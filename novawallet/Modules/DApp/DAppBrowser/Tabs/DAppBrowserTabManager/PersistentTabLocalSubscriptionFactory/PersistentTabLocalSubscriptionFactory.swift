import Foundation
import Operation_iOS

protocol PersistentTabLocalSubscriptionFactoryProtocol {
    func getTabsProvider(_ metaId: MetaAccountModel.Id?) -> StreamableProvider<DAppBrowserTab.PersistenceModel>
}

final class PersistentTabLocalSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?
    let operationQueue: OperationQueue

    private(set) var providerStore: [MetaAccountModel.Id: WeakWrapper] = [:]

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
}

// MARK: PersistentTabLocalSubscriptionFactoryProtocol

extension PersistentTabLocalSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol {
    func getTabsProvider(
        _ metaId: MetaAccountModel.Id?
    ) -> Operation_iOS.StreamableProvider<DAppBrowserTab.PersistenceModel> {
        runStoreCleaner()

        if
            let metaId,
            let provider = providerStore[metaId]?.target as? StreamableProvider<DAppBrowserTab.PersistenceModel>
        {
            return provider
        }

        let repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>

        let mapper = DAppBrowserTabMapper()
        if let metaId {
            let filter = NSPredicate.filterDAppBrowserTabs(by: metaId)
            repository = storageFacade.createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
        } else {
            repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        }

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: { entity in
                if let metaId {
                    entity.metaId == metaId
                } else {
                    true
                }
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<DAppBrowserTab.PersistenceModel>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        if let metaId {
            providerStore[metaId] = WeakWrapper(target: provider)
        }

        return provider
    }
}
