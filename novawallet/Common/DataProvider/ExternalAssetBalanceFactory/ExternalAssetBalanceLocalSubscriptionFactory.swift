import Foundation
import SubstrateSdk
import Operation_iOS

protocol ExternalBalanceLocalSubscriptionFactoryProtocol {
    func getExternalAssetBalanceProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>?

    func getAllExternalAssetBalanceProvider() -> StreamableProvider<ExternalAssetBalance>?
}

final class ExternalBalanceLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory {
    let eventCenter: EventCenterProtocol
    let serviceFactories: [ExternalAssetBalanceServiceFactoryProtocol]

    init(
        serviceFactories: [ExternalAssetBalanceServiceFactoryProtocol],
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.serviceFactories = serviceFactories

        super.init(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )
    }

    private func createAutomaticSyncServices(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [SyncServiceProtocol] {
        serviceFactories.flatMap { $0.createAutomaticSyncServices(for: chainAsset, accountId: accountId) }
    }

    private func createPollingSyncServices(
        chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [SyncServiceProtocol] {
        serviceFactories.flatMap { $0.createPollingSyncServices(for: chainAsset, accountId: accountId) }
    }
}

enum ExternalBalanceLocalSubscriptionFacade {
    static func createDefaultFactory(
        for storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) -> ExternalBalanceLocalSubscriptionFactory {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)
        let workingQueue = DispatchQueue.global(qos: .userInitiated)
        let logger = Logger.shared

        let crowdloanServiceFactory = CrowdloanExternalServiceFactory(
            storageFacade: storageFacade,
            chainRegistry: chainRegistry,
            operationFactory: CrowdloanOperationFactory(
                requestOperationFactory: StorageRequestFactory(
                    remoteFactory: StorageKeyFactory(),
                    operationManager: operationManager
                ),
                operationManager: operationManager
            ),
            paraIdOperationFactory: ParaIdOperationFactory.shared,
            operationQueue: operationQueue,
            logger: logger
        )

        let poolServiceFactory = NominationPoolExternalServiceFactory(
            storageFacade: storageFacade,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: Logger.shared
        )

        return ExternalBalanceLocalSubscriptionFactory(
            serviceFactories: [crowdloanServiceFactory, poolServiceFactory],
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension ExternalBalanceLocalSubscriptionFactory {
    static let shared: ExternalBalanceLocalSubscriptionFactory = {
        let storageFacade = SubstrateDataStorageFacade.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        return ExternalBalanceLocalSubscriptionFacade.createDefaultFactory(
            for: storageFacade,
            chainRegistry: chainRegistry
        )
    }()
}

extension ExternalBalanceLocalSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol {
    func getExternalAssetBalanceProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>? {
        let cacheKey = "externalBalances-\(accountId.toHex())-\(chainAsset.chainAssetId.stringValue)"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ExternalAssetBalance> {
            return provider
        }

        let automaticSyncServices = createAutomaticSyncServices(
            chainAsset: chainAsset,
            accountId: accountId
        )

        let pollingSyncServices = createPollingSyncServices(
            chainAsset: chainAsset,
            accountId: accountId
        )

        let source = ExternalAssetBalanceStreambleSource(
            automaticSyncServices: automaticSyncServices,
            pollingSyncServices: pollingSyncServices,
            chainAssetId: chainAsset.chainAssetId,
            accountId: accountId,
            eventCenter: eventCenter
        )

        let filter = NSPredicate.externalAssetBalance(
            for: chainAsset.chainAssetId,
            accountId: accountId
        )

        let mapper = ExternalAssetBalanceMapper()
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
                    chainAsset.chain.chainId == entity.chainId &&
                    chainAsset.asset.assetId == entity.assetId
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

    func getAllExternalAssetBalanceProvider() -> StreamableProvider<ExternalAssetBalance>? {
        let cacheKey = "allExternalBalances"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<ExternalAssetBalance> {
            return provider
        }

        let source = EmptyStreamableSource<ExternalAssetBalance>()
        let mapper = ExternalAssetBalanceMapper()
        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in
                true
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
