import Foundation
import RobinHood

protocol StakingDashboardProviderFactoryProtocol {
    func getDashboardItemsProvider(
        for walletId: MetaAccountModel.Id
    ) -> StreamableProvider<Multistaking.DashboardItem>?

    func getDashboardItemsProvider(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<Multistaking.DashboardItem>?
}

final class StakingDashboardProviderFactory: SubstrateLocalSubscriptionFactory {
    let repositoryFactory: MultistakingRepositoryFactoryProtocol

    override init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)

        super.init(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }
}

extension StakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol {
    func getDashboardItemsProvider(
        for walletId: MetaAccountModel.Id
    ) -> StreamableProvider<Multistaking.DashboardItem>? {
        let cacheKey = "dashboard-\(walletId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Multistaking.DashboardItem> {
            return provider
        }

        let repository = repositoryFactory.createDashboardRepository(for: walletId)
        let source = EmptyStreamableSource<Multistaking.DashboardItem>()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(StakingDashboardItemMapper()),
            predicate: { entity in entity.walletId == walletId }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Can't start storage observing: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getDashboardItemsProvider(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<Multistaking.DashboardItem>? {
        let cacheKey = "dashboard-\(walletId)-\(chainAssetId.stringValue)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Multistaking.DashboardItem> {
            return provider
        }

        let repository = repositoryFactory.createDashboardRepository(
            for: walletId,
            chainAssetId: chainAssetId
        )

        let source = EmptyStreamableSource<Multistaking.DashboardItem>()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(StakingDashboardItemMapper()),
            predicate: { entity in
                entity.walletId == walletId &&
                    entity.chainId == chainAssetId.chainId &&
                    entity.assetId == Int32(bitPattern: chainAssetId.assetId)
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Can't start storage observing: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
