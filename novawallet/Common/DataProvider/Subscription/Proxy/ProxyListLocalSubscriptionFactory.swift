import RobinHood

protocol ProxyListLocalSubscriptionFactoryProtocol {
    func getProxyListProvider() throws -> StreamableProvider<ProxyAccountModel>
}

final class ProxyListLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    static let shared = ProxyListLocalSubscriptionFactory(
        storageFacade: UserDataStorageFacade.shared,
        operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue),
        logger: Logger.shared
    )

    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }
}

extension ProxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol {
    func getProxyListProvider() throws -> StreamableProvider<ProxyAccountModel> {
        clearIfNeeded()

        let cacheKey = "proxy"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ProxyAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<ProxyAccountModel>()

        let mapper = ProxyAccountMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in true }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
