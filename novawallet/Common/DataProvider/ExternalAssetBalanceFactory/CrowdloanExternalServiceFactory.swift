import Foundation
import Operation_iOS

final class CrowdloanExternalServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationFactory: AhOpsOperationFactoryProtocol
    let paraIdOperationFactory: ParaIdOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationFactory: AhOpsOperationFactoryProtocol,
        paraIdOperationFactory: ParaIdOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.operationFactory = operationFactory
        self.paraIdOperationFactory = paraIdOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension CrowdloanExternalServiceFactory {
    func createOnChainSyncService(chainId: ChainModel.Id, accountId: AccountId) -> SyncServiceProtocol {
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
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension CrowdloanExternalServiceFactory: ExternalAssetBalanceServiceFactoryProtocol {
    func createAutomaticSyncServices(for chainAsset: ChainAsset, accountId: AccountId) -> [SyncServiceProtocol] {
        guard chainAsset.chain.hasCrowdloans, chainAsset.asset.isUtility else {
            return []
        }

        let chainId = chainAsset.chain.chainId

        let onchainSyncService = createOnChainSyncService(chainId: chainId, accountId: accountId)

        return [onchainSyncService]
    }

    func createPollingSyncServices(for _: ChainAsset, accountId _: AccountId) -> [SyncServiceProtocol] {
        []
    }
}
