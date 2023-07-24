import Foundation

protocol MultistakingSyncServiceFactoryProtocol {
    func createService(for wallet: MetaAccountModel) -> MultistakingSyncServiceProtocol
}

final class MultistakingSyncServiceFactory: MultistakingSyncServiceFactoryProtocol {
    let offchainUrl: URL
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        offchainUrl: URL,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.offchainUrl = offchainUrl
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

        let offchainOperationFactory = SubqueryMultistakingOperationFactory(url: offchainUrl)

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
