import Operation_iOS

protocol ProxyListLocalSubscriptionFactoryProtocol {
    func getProxyListProvider() throws -> StreamableProvider<DelegatedAccount.ProxyAccountModel>
    func getProxyListProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedProxyDefinition>
}

final class ProxyListLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    static let shared = ProxyListLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        streamableProviderFactory: SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        ),
        storageFacade: UserDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    let chainRegistry: ChainRegistryProtocol
    let streamableProviderFactory: SubstrateDataProviderFactoryProtocol
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        streamableProviderFactory: SubstrateDataProviderFactoryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.streamableProviderFactory = streamableProviderFactory
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }
}

extension ProxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol {
    func getProxyListProvider() throws -> StreamableProvider<DelegatedAccount.ProxyAccountModel> {
        clearIfNeeded()

        let cacheKey = "proxy"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<DelegatedAccount.ProxyAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<DelegatedAccount.ProxyAccountModel>()

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

    func getProxyListProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedProxyDefinition> {
        clearIfNeeded()

        let codingPath = Proxy.proxyList
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        if let dataProvider = getProvider(for: localKey) as? DataProvider<DecodedProxyDefinition> {
            return AnyDataProvider(dataProvider)
        }

        guard let runtimeCodingProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let repository = InMemoryDataProviderRepository<DecodedProxyDefinition>()

        let streamableProvider = streamableProviderFactory.createStorageProvider(for: localKey)
        let fallback = StorageProviderSourceFallback<ProxyDefinition>.init(
            usesRuntimeFallback: false,
            missingEntryStrategy: .defaultValue(nil)
        )
        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<ProxyDefinition> = StorageProviderSource(
            itemIdentifier: localKey,
            possibleCodingPaths: [codingPath],
            runtimeService: runtimeCodingProvider,
            provider: streamableProvider,
            trigger: trigger,
            fallback: fallback,
            operationManager: operationManager
        )

        let dataProvider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        saveProvider(dataProvider, for: localKey)

        return AnyDataProvider(dataProvider)
    }
}
