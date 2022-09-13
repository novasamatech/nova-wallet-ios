import SubstrateSdk
import RobinHood

protocol CrowdloanContributionLocalSubscriptionFactoryProtocol {
    func getCrowdloanContributionDataProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<CrowdloanContributionData>?
}

final class CrowdloanContributionLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory, CrowdloanContributionLocalSubscriptionFactoryProtocol {
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        operationQueue: OperationQueue,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol
    ) {
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.operationQueue = operationQueue

        super.init(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
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

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let mapper = CrowdloanContributionDataMapper()
        let onChainFilter = NSPredicate.crowdloanContribution(
            for: chain.chainId,
            accountId: accountId,
            source: nil
        )
        let onChainCrowdloansRepository = storageFacade.createRepository(
            filter: onChainFilter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let operationFactory = CrowdloanContributionOperationFactory(
            factory: crowdloanOperationFactory,
            connection: connection,
            runtimeService: runtimeService
        )
        let onChainSyncService = CrowdloanOnChainSyncService(
            remoteOperationsFactory: operationFactory,
            operationQueue: operationQueue,
            repository: AnyDataProviderRepository(onChainCrowdloansRepository),
            accountId: accountId,
            chainId: chain.chainId
        )
        let syncServices = [onChainSyncService]

        let source = CrowdloanContributionStreamableSource(syncServices: syncServices)

        let filter = NSPredicate.crowdloanContribution(
            for: chain.chainId,
            accountId: accountId,
            source: nil
        )

        let repository = storageFacade.createRepository(
            filter: filter,
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
}
