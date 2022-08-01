import Foundation
import RobinHood

protocol WalletListLocalSubscriptionFactoryProtocol {
    func getWalletsProvider() throws -> StreamableProvider<ManagedMetaAccountModel>
}

final class WalletListLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    static let shared = WalletListLocalSubscriptionFactory(
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

extension WalletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol {
    func getWalletsProvider() throws -> StreamableProvider<ManagedMetaAccountModel> {
        clearIfNeeded()

        let cacheKey = "all-wallets"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ManagedMetaAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<ManagedMetaAccountModel>()

        let mapper = ManagedMetaAccountMapper()
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
