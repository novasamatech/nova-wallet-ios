import Foundation
import Operation_iOS
import SubstrateSdk

protocol NftLocalSubscriptionFactoryProtocol {
    func getNftProvider(for wallet: MetaAccountModel, chains: [ChainModel]) -> StreamableProvider<NftModel>
}

final class NftLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    NftLocalSubscriptionFactoryProtocol {
    static let shared = NftLocalSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared,
        operationQueue: OperationManagerFacade.nftQueue
    )

    typealias NftOption = (chain: ChainModel, ownerId: AccountId, type: NftType)

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

    private func createSyncRepository(
        for chain: ChainModel,
        ownerId: AccountId,
        type: NftType
    ) -> AnyDataProviderRepository<NftModel> {
        let mapper = AnyCoreDataMapper(NftModelMapper())
        let filter = NSPredicate.nfts(for: [(chain.chainId, ownerId)], type: type)
        let sortDescriptor = NSSortDescriptor.nftsByCreationDesc
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [sortDescriptor],
            mapper: mapper
        )

        return AnyDataProviderRepository(repository)
    }

    private func createClearService() -> NftSyncServiceProtocol? {
        let excludedTypes = NftType.excludedTypes

        guard !excludedTypes.isEmpty else {
            return nil
        }

        let mapper = AnyCoreDataMapper(NftModelMapper())
        let filter = NSPredicate.nftsForTypes(excludedTypes)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: mapper
        )

        return NFTClearService(
            repository: AnyDataProviderRepository(repository),
            operationQueue: operationQueue,
            retryStrategy: ExponentialReconnection(),
            logger: logger
        )
    }

    private func createUniquesService(
        for chain: ChainModel,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        let repository = createSyncRepository(for: chain, ownerId: ownerId, type: .uniques)

        return UniquesSyncService(
            chainRegistry: chainRegistry,
            ownerId: ownerId,
            chainId: chain.chainId,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createRMRKV1Service(
        for chain: ChainModel,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        let repository = createSyncRepository(for: chain, ownerId: ownerId, type: .rmrkV1)

        return RMRKV1SyncService(
            ownerId: ownerId,
            chain: chain,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createRMRKV2Service(
        for chain: ChainModel,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        let repository = createSyncRepository(for: chain, ownerId: ownerId, type: .rmrkV2)

        return RMRKV2SyncService(
            ownerId: ownerId,
            chain: chain,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createPdc20Service(for chain: ChainModel, ownerId: AccountId) -> NftSyncServiceProtocol {
        let repository = createSyncRepository(for: chain, ownerId: ownerId, type: .pdc20)

        return Pdc20NftSyncService(
            ownerId: ownerId,
            chain: chain,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createKodaDotService(for chain: ChainModel, ownerId: AccountId) -> NftSyncServiceProtocol? {
        guard let apiUrl = KodaDotAssetHubApi.apiForChain(chain.chainId) else {
            return nil
        }

        let repository = createSyncRepository(for: chain, ownerId: ownerId, type: .kodadot)

        return KodaDotNftSyncService(
            api: apiUrl,
            ownerId: ownerId,
            chain: chain,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createUniqueNetworkService(
        for chain: ChainModel,
        ownerId: AccountId
    ) -> NftSyncServiceProtocol {
        let repository = createSyncRepository(
            for: chain,
            ownerId: ownerId,
            type: .unique
        )

        return UniqueNftSyncService(
            api: UniqueScanApi.mainnet,
            ownerId: ownerId,
            chain: chain,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    private func createService(
        for chain: ChainModel,
        ownerId: AccountId,
        type: NftType
    ) -> NftSyncServiceProtocol? {
        switch type {
        case .uniques:
            return createUniquesService(for: chain, ownerId: ownerId)
        case .rmrkV1:
            return createRMRKV1Service(for: chain, ownerId: ownerId)
        case .rmrkV2:
            return createRMRKV2Service(for: chain, ownerId: ownerId)
        case .pdc20:
            return createPdc20Service(for: chain, ownerId: ownerId)
        case .kodadot:
            return createKodaDotService(for: chain, ownerId: ownerId)
        case .unique:
            return createUniqueNetworkService(for: chain, ownerId: ownerId)
        }
    }

    private func createNftOptions(for wallet: MetaAccountModel, chains: [ChainModel]) -> [NftOption] {
        let options: [[NftOption]] = chains.map { chain in
            let sources = chain.nftSources

            guard
                !sources.isEmpty,
                let ownerId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                return []
            }

            return sources.map { source in
                NftOption(chain: chain, ownerId: ownerId, type: source.type)
            }
        }

        return options.flatMap { $0 }
    }

    func getNftProvider(
        for wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> StreamableProvider<NftModel> {
        let identifier = wallet.identifier

        if let provider = getProvider(for: identifier) as? StreamableProvider<NftModel> {
            return provider
        }

        let nftOptions = createNftOptions(for: wallet, chains: chains)

        var syncServices = nftOptions.compactMap { option in
            createService(for: option.chain, ownerId: option.ownerId, type: option.type)
        }

        if let clearService = createClearService() {
            syncServices.insert(clearService, at: 0)
        }

        let dataSource = NftStreamableSource(syncServices: syncServices)

        /**
         *  We can now have cases:
         *  1) When we don't sync nfts (don't have source for it) but want to display it from cache (rmrk v1).
         *  2) Don't have source for nfts and don't want to display them from cache (uniques).
         *  Probably we want to remove such nfts from cache and don't provide source for them in future.
         */

        let mapper = AnyCoreDataMapper(NftModelMapper())
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: mapper,
            predicate: { entity in
                let option = nftOptions.first { option in
                    entity.chainId == option.chain.chainId &&
                        entity.ownerId == option.ownerId.toHex() &&
                        entity.type == option.type.rawValue
                }

                return option != nil
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let filterOptions = nftOptions.map { ($0.chain.chainId, $0.ownerId) }
        let filter = NSPredicate.nfts(for: filterOptions)
        let sortDescriptor = NSSortDescriptor.nftsByCreationDesc
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [sortDescriptor],
            mapper: AnyCoreDataMapper(NftModelMapper())
        )

        let provider = StreamableProvider(
            source: AnyStreamableSource(dataSource),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        return provider
    }
}
