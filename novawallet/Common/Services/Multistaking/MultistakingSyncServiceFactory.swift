import Foundation

protocol MultistakingSyncServiceFactoryProtocol {
    func createService(for wallet: MetaAccountModel) -> MultistakingSyncServiceProtocol
}

final class MultistakingSyncServiceFactory: MultistakingSyncServiceFactoryProtocol {
    let configProvider: GlobalConfigProviding
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        configProvider: GlobalConfigProviding,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.configProvider = configProvider
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
            configProvider: configProvider,
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
