import Foundation
import RobinHood

protocol DAppLocalSubscriptionFactoryProtocol {
    func getFavoritesProvider(_ identifier: String?) -> StreamableProvider<DAppFavorite>
    func getAuthorizedProvider(for metaId: String) -> StreamableProvider<DAppSettings>
}

extension DAppLocalSubscriptionFactoryProtocol {
    func getFavoritesProvider() -> StreamableProvider<DAppFavorite> {
        getFavoritesProvider(nil)
    }
}

final class DAppLocalSubscriptionFactory {
    static let shared = DAppLocalSubscriptionFactory(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

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
}

extension DAppLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol {
    func getFavoritesProvider(_ identifier: String?) -> StreamableProvider<DAppFavorite> {
        runStoreCleaner()

        let key = "favorites" + (identifier ?? "")

        if let provider = providerStore[key]?.target as? StreamableProvider<DAppFavorite> {
            return provider
        }

        let repository: CoreDataRepository<DAppFavorite, CDDAppFavorite>

        let mapper = DAppFavoriteMapper()
        if let identifier = identifier {
            let filter = NSPredicate.filterFavoriteDApps(by: identifier)
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
                if let identifier = identifier {
                    return entity.identifier == identifier
                } else {
                    return true
                }
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<DAppFavorite>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providerStore[key] = WeakWrapper(target: provider)

        return provider
    }

    func getAuthorizedProvider(for metaId: String) -> StreamableProvider<DAppSettings> {
        runStoreCleaner()

        let key = "authorized" + metaId

        if let provider = providerStore[key]?.target as? StreamableProvider<DAppSettings> {
            return provider
        }

        let repository: CoreDataRepository<DAppSettings, CDDAppSettings>

        let mapper = DAppSettingsMapper()
        let filter = NSPredicate.filterAuthorizedDApps(by: metaId)
        repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: { entity in
                entity.metaId == metaId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<DAppSettings>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providerStore[key] = WeakWrapper(target: provider)

        return provider
    }
}
