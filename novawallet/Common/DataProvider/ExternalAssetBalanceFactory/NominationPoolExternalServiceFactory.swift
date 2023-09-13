import Foundation
import RobinHood

final class NominationPoolExternalServiceFactory {
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

extension NominationPoolExternalServiceFactory: ExternalAssetBalanceServiceFactoryProtocol {
    func createAutomaticSyncServices(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [SyncServiceProtocol] {
        guard let stakings = chainAsset.asset.stakings, stakings.contains(.nominationPools) else {
            return []
        }

        let chainId = chainAsset.chain.chainId

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return []
        }

        let mapper = PooledAssetBalanceMapper()

        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let service = PooledBalanceUpdatingService(
            accountId: accountId,
            chainAsset: chainAsset,
            repository: AnyDataProviderRepository(repository),
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: Logger.shared
        )

        return [service]
    }

    func createPollingSyncServices(
        for _: ChainAsset,
        accountId _: AccountId
    ) -> [SyncServiceProtocol] {
        []
    }
}
