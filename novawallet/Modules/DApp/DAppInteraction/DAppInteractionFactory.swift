import Foundation

final class DAppInteractionFactory {
    func createMediator() -> DAppInteractionMediating {
        let logger = Logger.shared

        let presenter = DAppInteractionPresenter(logger: logger)

        let storageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let settingsRepository = accountRepositoryFactory.createAuthorizedDAppsRepository(for: nil)

        let phishingVerifier = PhishingSiteVerifier.createSequentialVerifier()

        let mediator = DAppInteractionMediator(
            presenter: presenter,
            children: [],
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settingsRepository: settingsRepository,
            securedLayer: SecurityLayerService.shared,
            sequentialPhishingVerifier: phishingVerifier,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: logger
        )

        presenter.interactor = mediator

        return mediator
    }
}
