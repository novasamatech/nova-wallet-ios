import Foundation
import RobinHood

protocol NftLocalSubscriptionFactoryProtocol {
    func getNftProvider(for wallet: MetaAccountModel, chains: [ChainModel]) -> StreamableProvider<NftModel>
}

final class NftLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
                                         NftLocalSubscriptionFactoryProtocol {
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationQueue = operationQueue

        super.init(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createUniquesService(
        for chainId: ChainModel.Id,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        let mapper = AnyCoreDataMapper(NftModelMapper())

        let filter = NSPredicate.nfts(for: [(chainId, ownerId)], type: NftType.uniques.rawValue)
        let sortDescriptor = NSSortDescriptor.nftsByCreationDesc
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [sortDescriptor],
            mapper: mapper
        )

        return UniquesSyncService(
            chainRegistry: chainRegistry,
            ownerId: ownerId,
            chainId: chainId,
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )
    }

    private func createRMRKV1Service(
        for chainId: ChainModel.Id,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        RMRKV1SyncService()
    }

    private func createRMRKV2Service(
        for chainId: ChainModel.Id,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        RMRKV2SyncService()
    }

    private func createService(
        for chainId: ChainModel.Id,
        ownerId: AccountId,
        type: NftType
    ) -> NftSyncServiceProtocol {
        switch type {
        case .uniques:
            return createUniquesService(for: chainId, ownerId: ownerId)
        case .rmrkV1:
            return createRMRKV1Service(for: chainId, ownerId: ownerId)
        case .rmrkV2:
            return createRMRKV2Service(for: chainId, ownerId: ownerId)
        }
    }

    func getNftProvider(
        for wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> StreamableProvider<NftModel> {
        let identifier = ownerId.toHex()

        if let provider = getProvider(for: identifier) as? StreamableProvider<NftModel> {
            return provider
        }

        let mapper = AnyCoreDataMapper(NftModelMapper())
        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: mapper
        )

        let statemineService = UniquesSyncService(
            chainRegistry: chainRegistry,
            ownerId: ownerId,
            chainId: "",
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue
        )

        let dataSource = NftStreamableSource(syncServices: [statemineService])

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: mapper,
            predicate: { entity in
                return true
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(dataSource),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        return provider
    }
}
