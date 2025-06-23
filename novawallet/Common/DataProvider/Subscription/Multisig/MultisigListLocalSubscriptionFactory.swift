import Operation_iOS

protocol MultisigListLocalSubscriptionFactoryProtocol {
    func getMultisigListProvider() throws -> StreamableProvider<DelegatedAccount.MultisigAccountModel>

    func getPendingOperatonsProvider(
        for multisigAccountId: AccountId
    ) throws -> StreamableProvider<Multisig.PendingOperation>
}

final class MultisigListLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    static let shared = MultisigListLocalSubscriptionFactory(
        storageFacade: UserDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
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

extension MultisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactoryProtocol {
    func getMultisigListProvider() throws -> StreamableProvider<DelegatedAccount.MultisigAccountModel> {
        clearIfNeeded()

        let cacheKey = "multisig"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<DelegatedAccount.MultisigAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<DelegatedAccount.MultisigAccountModel>()

        let mapper = MultisigAccountMapper()
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

    func getPendingOperatonsProvider(
        for multisigAccountId: AccountId
    ) throws -> StreamableProvider<Multisig.PendingOperation> {
        clearIfNeeded()

        let cacheKey = "multisigPendingOperations"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Multisig.PendingOperation> {
            return provider
        }

        let source = EmptyStreamableSource<Multisig.PendingOperation>()

        let mapper = MultisigPendingOperationMapper()

        let repository = storageFacade.createRepository(
            filter: NSPredicate.pendingMultisigOperations(multisigAccountId: multisigAccountId),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

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
