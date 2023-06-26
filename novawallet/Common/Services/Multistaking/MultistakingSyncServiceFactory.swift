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

        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let providerFactory = MultistakingProviderFactory(
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue
        )

        let offchainOperationFactory = SubqueryMultistakingOperationFactory(url: offchainUrl)

        return MultistakingSyncService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            providerFactory: providerFactory,
            repositoryFactory: repositoryFactory,
            offchainOperationFactory: offchainOperationFactory
        )
    }
}
