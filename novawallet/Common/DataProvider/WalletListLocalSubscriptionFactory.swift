import Foundation
import Operation_iOS

protocol WalletListLocalSubscriptionFactoryProtocol {
    func getWalletProvider(for walletId: String) throws -> StreamableProvider<ManagedMetaAccountModel>
    func getSelectedWalletProvider() throws -> StreamableProvider<ManagedMetaAccountModel>
    func getWalletsProvider() throws -> StreamableProvider<ManagedMetaAccountModel>
    func getWalletsProvider(for walletType: MetaAccountModelType) throws -> StreamableProvider<ManagedMetaAccountModel>
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

// MARK: Private

private extension WalletListLocalSubscriptionFactory {
    func getWalletProvider(
        cacheKey: String,
        with filter: NSPredicate?,
        predicateClosure: @escaping (ManagedMetaAccountMapper.CoreDataEntity) -> Bool
    ) throws -> StreamableProvider<ManagedMetaAccountModel> {
        clearIfNeeded()

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ManagedMetaAccountModel> {
            return provider
        }

        let source = EmptyStreamableSource<ManagedMetaAccountModel>()

        let mapper = ManagedMetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: predicateClosure
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

// MARK: WalletListLocalSubscriptionFactoryProtocol

extension WalletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol {
    func getWalletProvider(for walletId: String) throws -> StreamableProvider<ManagedMetaAccountModel> {
        try getWalletProvider(
            cacheKey: CacheKeys.wallet(with: walletId),
            with: NSPredicate.metaAccountById(walletId),
            predicateClosure: { entity in entity.metaId == walletId }
        )
    }

    func getSelectedWalletProvider() throws -> StreamableProvider<ManagedMetaAccountModel> {
        try getWalletProvider(
            cacheKey: CacheKeys.selectedWallet,
            with: NSPredicate.selectedMetaAccount(),
            predicateClosure: { $0.isSelected }
        )
    }

    func getWalletsProvider() throws -> StreamableProvider<ManagedMetaAccountModel> {
        try getWalletProvider(
            cacheKey: CacheKeys.allWallets,
            with: nil,
            predicateClosure: { _ in true }
        )
    }

    func getWalletsProvider(
        for walletType: MetaAccountModelType
    ) throws -> StreamableProvider<ManagedMetaAccountModel> {
        try getWalletProvider(
            cacheKey: CacheKeys.wallets(of: walletType),
            with: NSPredicate.metaAccountsByType(walletType),
            predicateClosure: { entity in entity.type == walletType.rawValue }
        )
    }
}

// MARK: CacheKeys

private extension WalletListLocalSubscriptionFactory {
    enum CacheKeys {
        static var allWallets: String {
            "all-wallets"
        }

        static var selectedWallet: String {
            "selected-wallet"
        }

        static func wallet(with id: String) -> String {
            "wallet-\(id)"
        }

        static func wallets(of type: MetaAccountModelType) -> String {
            "wallets-\(type.rawValue)"
        }
    }
}
