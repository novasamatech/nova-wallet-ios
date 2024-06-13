import Foundation
import Operation_iOS

final class CrowdloanExternalServiceFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationFactory: CrowdloanOperationFactoryProtocol
    let paraIdOperationFactory: ParaIdOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationFactory: CrowdloanOperationFactoryProtocol,
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
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )
    }

    private func createOffChainSyncServices(
        from sources: [ExternalContributionSourceProtocol],
        chain: ChainModel,
        accountId: AccountId
    ) -> [SyncServiceProtocol] {
        let mapper = CrowdloanContributionDataMapper()

        return sources.map { source in
            let chainFilter = NSPredicate.crowdloanContribution(
                for: chain.chainId,
                accountId: accountId,
                source: source.sourceName
            )

            let serviceRepository = storageFacade.createRepository(
                filter: chainFilter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

            return CrowdloanOffChainSyncService(
                source: source,
                chain: chain,
                accountId: accountId,
                operationManager: OperationManager(operationQueue: operationQueue),
                repository: AnyDataProviderRepository(serviceRepository),
                logger: logger
            )
        }
    }
}

extension CrowdloanExternalServiceFactory: ExternalAssetBalanceServiceFactoryProtocol {
    func createAutomaticSyncServices(for _: ChainAsset, accountId _: AccountId) -> [SyncServiceProtocol] {
        []
    }

    func createPollingSyncServices(for chainAsset: ChainAsset, accountId: AccountId) -> [SyncServiceProtocol] {
        guard chainAsset.chain.hasCrowdloans, chainAsset.asset.isUtility else {
            return []
        }

        let chainId = chainAsset.chain.chainId

        let onchainSyncService = createOnChainSyncService(chainId: chainId, accountId: accountId)

        let offchainSources = ExternalContributionSourcesFactory.createExternalSources(
            for: chainId,
            paraIdOperationFactory: paraIdOperationFactory
        )

        let offChainSyncServices = createOffChainSyncServices(
            from: offchainSources,
            chain: chainAsset.chain,
            accountId: accountId
        )

        return [onchainSyncService] + offChainSyncServices
    }
}
