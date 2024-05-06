import Foundation

protocol MultistakingSyncServiceFactoryProtocol {
    func createService(for wallet: MetaAccountModel) -> MultistakingSyncServiceProtocol
}

final class MultistakingSyncServiceFactory: MultistakingSyncServiceFactoryProtocol {
    let stakingConfigProvider: StakingGlobalConfigProviding
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        stakingConfigProvider: StakingGlobalConfigProviding,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.stakingConfigProvider = stakingConfigProvider
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
    }

    func createService(for wallet: MetaAccountModel) -> MultistakingSyncServiceProtocol {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let multistakingRepositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let substrateRepositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let providerFactory = MultistakingProviderFactory(
            repositoryFactory: multistakingRepositoryFactory,
            operationQueue: operationQueue
        )

        let offchainOperationFactory = SubqueryMultistakingProxy(
            configProvider: stakingConfigProvider,
            operationQueue: operationQueue
        )

        return MultistakingSyncService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            providerFactory: providerFactory,
            multistakingRepositoryFactory: multistakingRepositoryFactory,
            substrateRepositoryFactory: substrateRepositoryFactory,
            offchainOperationFactory: offchainOperationFactory
        )
    }
}
