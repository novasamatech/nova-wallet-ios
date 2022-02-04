import Foundation
import RobinHood

protocol WalletLocalSubscriptionFactoryProtocol {
    func getAccountProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo>

    func getAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) throws -> StreamableProvider<AssetBalance>

    func getAccountBalanceProvider(for accountId: AccountId) throws -> StreamableProvider<AssetBalance>
}

final class WalletLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    WalletLocalSubscriptionFactoryProtocol {
    static let shared = WalletLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    func getAccountProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let codingPath = StorageCodingPath.account
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
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
                    assetId == entity.assetId
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

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                accountId.toHex() == entity.chainAccountId
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
}
