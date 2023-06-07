import Foundation

enum MultistakingServiceFactory {
    static func createService(
        for wallet: MetaAccountModel,
        offchainUrl: URL,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) -> MultistakingSyncServiceProtocol {
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
