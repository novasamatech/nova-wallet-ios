import SubstrateSdk
import RobinHood

protocol CrowdloanContributionLocalSubscriptionFactoryProtocol {
    func getCrowdloanContributionDataProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<CrowdloanContributionData>?
}

final class CrowdloanContributionLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    CrowdloanContributionLocalSubscriptionFactoryProtocol {
    let operationFactory: CrowdloanOperationFactoryProtocol

    init(
        operationFactory: CrowdloanOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }

    func getCrowdloanContributionDataProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<CrowdloanContributionData>? {
        let cacheKey = "crowdloanContributions-\(accountId.toHex())-\(chain.chainId)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<CrowdloanContributionData> {
            return provider
        }

        let onChainSyncService = createOnChainSyncService(chainId: chain.chainId, accountId: accountId)

        let syncServices = [onChainSyncService]

        let source = CrowdloanContributionStreamableSource(syncServices: syncServices)

        let crowdloansFilter = NSPredicate.crowdloanContribution(
            for: chain.chainId,
            accountId: accountId
        )

        let mapper = CrowdloanContributionDataMapper()
        let repository = storageFacade.createRepository(
            filter: crowdloansFilter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                accountId.toHex() == entity.chainAccountId &&
                    chain.chainId == entity.chainId
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

    private func createOnChainSyncService(chainId: ChainModel.Id, accountId: AccountId) -> SyncServiceProtocol {
        let mapper = CrowdloanContributionDataMapper()
        let onChainFilter = NSPredicate.crowdloanContribution(
            for: chainId,
            accountId: accountId,
            source: nil
        )
        let onChainCrowdloansRepository = storageFacade.createRepository(
            filter: onChainFilter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        return CrowdloanOnChainSyncService(
            operationFactory: operationFactory,
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(onChainCrowdloansRepository),
            accountId: accountId,
            chainId: chainId,
            operationManager: operationManager,
            logger: logger
        )
    }
}

extension CrowdloanContributionLocalSubscriptionFactory {
    static let operationManager = OperationManagerFacade.sharedManager

    static let shared = CrowdloanContributionLocalSubscriptionFactory(
        operationFactory: CrowdloanOperationFactory(
            requestOperationFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: operationManager
            ),
            operationManager: operationManager
        ),
        operationManager: operationManager,
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        logger: Logger.shared
    )
}
