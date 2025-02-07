import Foundation
import Operation_iOS

protocol WalletLocalSubscriptionFactoryProtocol {
    func getAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetBalance>

    func getAccountBalanceProvider(for accountId: AccountId) throws -> StreamableProvider<AssetBalance>

    func getAllBalancesProvider() throws -> StreamableProvider<AssetBalance>

    func getLocksProvider(for accountId: AccountId) throws -> StreamableProvider<AssetLock>

    func getLocksProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetLock>

    func getHoldsProvider(for accountId: AccountId) throws -> StreamableProvider<AssetHold>

    func getHoldsProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetHold>
}

final class WalletLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    WalletLocalSubscriptionFactoryProtocol {
    static let shared = WalletLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    private func createStreamableProcessingQueue() -> DispatchQueue {
        DispatchQueue(
            label: "com.streamableprovider.repository.queue.\(UUID().uuidString)",
            qos: .userInitiated
        )
    }

    func getAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetBalance> {
        let cacheKey = "\(chainId)-\(assetId)-\(accountId.toHex())"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetBalance> {
            return provider
        }

        let source = EmptyStreamableSource<AssetBalance>()

        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(for: accountId, chainId: chainId, assetId: assetId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                accountId.toHex() == entity.chainAccountId && chainId == entity.chainId &&
                    assetId == UInt32(bitPattern: entity.assetId)
            }
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

    func getAccountBalanceProvider(for accountId: AccountId) throws -> StreamableProvider<AssetBalance> {
        let cacheKey = "account-\(accountId.toHex())"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetBalance> {
            return provider
        }

        let source = EmptyStreamableSource<AssetBalance>()

        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(for: accountId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let processingQueue = createStreamableProcessingQueue()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                accountId.toHex() == entity.chainAccountId
            },
            processingQueue: processingQueue
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
            operationManager: operationManager,
            serialQueue: processingQueue
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getAllBalancesProvider() throws -> StreamableProvider<AssetBalance> {
        let cacheKey = "all-balances"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetBalance> {
            return provider
        }

        let source = EmptyStreamableSource<AssetBalance>()

        let mapper = AssetBalanceMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let processingQueue = createStreamableProcessingQueue()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in true },
            processingQueue: processingQueue
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
            operationManager: operationManager,
            serialQueue: processingQueue
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getLocksProvider(for accountId: AccountId) throws -> StreamableProvider<AssetLock> {
        let cacheKey = "locks-\(accountId.toHex())"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetLock> {
            return provider
        }

        let filter = NSPredicate.assetLock(for: accountId)

        let provider = createAssetLocksProvider(for: filter) { entity in
            accountId.toHex() == entity.chainAccountId
        }

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getLocksProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetLock> {
        let cacheKey = "locks-\(accountId.toHex())-\(chainId)-\(assetId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetLock> {
            return provider
        }

        let filter = NSPredicate.assetLock(
            for: accountId,
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetId)
        )

        let provider = createAssetLocksProvider(for: filter) { entity in
            accountId.toHex() == entity.chainAccountId &&
                chainId == entity.chainId &&
                assetId == entity.assetId
        }

        saveProvider(provider, for: cacheKey)

        return provider
    }

    private func createAssetLocksProvider(
        for repositoryFilter: NSPredicate,
        observingFilter: @escaping (CDAssetLock) -> Bool
    ) -> StreamableProvider<AssetLock> {
        let source = EmptyStreamableSource<AssetLock>()

        let mapper = AssetLockMapper()

        let repository = storageFacade.createRepository(
            filter: repositoryFilter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let processingQueue = createStreamableProcessingQueue()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                observingFilter(entity)
            },
            processingQueue: processingQueue
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }

    func getHoldsProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetHold> {
        let cacheKey = "holds-\(accountId.toHex())-\(chainId)-\(assetId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetHold> {
            return provider
        }

        let filter = NSPredicate.assetHold(
            for: accountId,
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetId)
        )

        let provider = createAssetHoldsProvider(for: filter) { entity in
            accountId.toHex() == entity.chainAccountId &&
                chainId == entity.chainId &&
                assetId == entity.assetId
        }

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getHoldsProvider(for accountId: AccountId) throws -> StreamableProvider<AssetHold> {
        let cacheKey = "holds-\(accountId.toHex())"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetHold> {
            return provider
        }

        let filter = NSPredicate.assetHold(for: accountId)

        let provider = createAssetHoldsProvider(for: filter) { entity in
            accountId.toHex() == entity.chainAccountId
        }

        saveProvider(provider, for: cacheKey)

        return provider
    }

    private func createAssetHoldsProvider(
        for repositoryFilter: NSPredicate,
        observingFilter: @escaping (CDAssetHold) -> Bool
    ) -> StreamableProvider<AssetHold> {
        let source = EmptyStreamableSource<AssetHold>()

        let mapper = AssetHoldMapper()

        let repository = storageFacade.createRepository(
            filter: repositoryFilter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let processingQueue = createStreamableProcessingQueue()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                observingFilter(entity)
            },
            processingQueue: processingQueue
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager,
            serialQueue: processingQueue
        )
    }
}
