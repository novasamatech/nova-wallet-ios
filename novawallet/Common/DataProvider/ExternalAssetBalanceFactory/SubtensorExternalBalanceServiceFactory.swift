import Foundation
import Operation_iOS

final class SubtensorExternalBalanceServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
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

        let chainId = chainAsset.chain.chainId

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return []
        }

        let mapper = SubtensorStakedBalanceMapper()

        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let runtimeConnectionStore = ChainRegistryRuntimeConnectionStore(
            chainId: chainId,
            chainRegistry: chainRegistry
        )

        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: operationQueue
        )

        let stakeStateFetchFactory = SubtensorStakeStateFetchFactory(
            operationFactory: apiOperationFactory,
            operationQueue: operationQueue
        )

        let service = SubtensorStakedBalanceUpdatingService(
            accountId: accountId,
            chainAsset: chainAsset,
            repository: AnyDataProviderRepository(repository),
            stakeStateFetchFactory: stakeStateFetchFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        return [service]
    }
}
