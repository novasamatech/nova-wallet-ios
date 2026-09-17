import Foundation
import Operation_iOS

protocol AssetVisibilityLocalSubscriptionFactoryProtocol {
    func getVisibilityProvider(for metaId: MetaAccountModel.Id) -> StreamableProvider<AssetVisibilityLocal>
    func getSettingsProvider(for metaId: MetaAccountModel.Id) -> StreamableProvider<MetaAccountSettingsLocal>
}

final class AssetVisibilityLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory {
    static let shared = AssetVisibilityLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: UserDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )
}

extension AssetVisibilityLocalSubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol {
    func getVisibilityProvider(for metaId: MetaAccountModel.Id) -> StreamableProvider<AssetVisibilityLocal> {
        let cacheKey = "asset-visibility-\(metaId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<AssetVisibilityLocal> {
            return provider
        }

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(AssetVisibilityMapper()),
            predicate: { entity in metaId == entity.metaId }
        )

        startObserving(observable)

        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
            for: metaId,
            using: storageFacade
        )

        let provider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<AssetVisibilityLocal>()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getSettingsProvider(for metaId: MetaAccountModel.Id) -> StreamableProvider<MetaAccountSettingsLocal> {
        let cacheKey = "meta-account-settings-\(metaId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<MetaAccountSettingsLocal> {
            return provider
        }

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(MetaAccountSettingsMapper()),
            predicate: { entity in metaId == entity.metaId }
        )

        startObserving(observable)

        let repository = AssetVisibilityRepositoryFactory.createSettingsRepository(
            for: metaId,
            using: storageFacade
        )

        let provider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<MetaAccountSettingsLocal>()),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}

// MARK: Private

private extension AssetVisibilityLocalSubscriptionFactory {
    func startObserving<T, U>(_ observable: CoreDataContextObservable<T, U>) {
        observable.start { [weak self] error in
            if let error {
                self?.logger.error("Did receive error: \(error)")
            }
        }
    }
}
