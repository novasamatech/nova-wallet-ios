import Foundation
import RobinHood

protocol WalletListLocalSubscriptionFactoryProtocol {
    func getWalletProvider(for walletId: String) throws -> StreamableProvider<ManagedMetaAccountModel>
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
    func getWalletProvider(for walletId: String) throws -> StreamableProvider<ManagedMetaAccountModel> {
        clearIfNeeded()

        let cacheKey = "wallet-\(walletId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ManagedMetaAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<ManagedMetaAccountModel>()

        let mapper = ManagedMetaAccountMapper()

        let filter = NSPredicate.metaAccountById(walletId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in entity.metaId == walletId }
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
