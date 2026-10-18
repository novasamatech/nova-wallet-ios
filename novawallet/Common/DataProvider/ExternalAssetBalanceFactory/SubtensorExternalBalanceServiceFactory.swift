import Foundation
import Operation_iOS

final class SubtensorExternalBalanceServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let processServices: SubtensorStakingProcessServices

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        processServices: SubtensorStakingProcessServices
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.processServices = processServices
    }
}

extension SubtensorExternalBalanceServiceFactory: ExternalAssetBalanceServiceFactoryProtocol {
    func createAutomaticSyncServices(
        for _: ChainAsset,
        accountId _: AccountId
    ) -> [SyncServiceProtocol] {
        []
    }

    // Registered as polling so refresh/AssetBalanceChanged re-drive the sync: the storage triggers
    // alone miss a stake to an already-tracked hotkey on a new subnet
    func createPollingSyncServices(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [SyncServiceProtocol] {
        guard chainAsset.asset.hasSubtensorStaking else {
            return []
        }

        guard
            let stakeStateSource = processServices.stakeStateSourceFactory.getSource(
                for: accountId,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry
            ) else {
            return []
        }

        let mapper = SubtensorStakedBalanceMapper()

        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let runtimeConnectionStore = ChainRegistryRuntimeConnectionStore(
            chainId: chainAsset.chain.chainId,
            chainRegistry: chainRegistry
        )

        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: operationQueue
        )

        let service = SubtensorStakedBalanceUpdatingService(
            accountId: accountId,
            chainAsset: chainAsset,
            repository: AnyDataProviderRepository(repository),
            stakeStateSource: stakeStateSource,
            cataloguePricing: processServices.createCataloguePricingTracker(
                chainOperationFactory: apiOperationFactory,
                operationQueue: operationQueue,
                logger: logger
            ),
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        return [service]
    }
}
