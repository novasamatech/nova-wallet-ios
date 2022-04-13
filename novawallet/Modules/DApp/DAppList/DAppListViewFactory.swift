import Foundation
import SoraFoundation
import RobinHood

struct DAppListViewFactory {
    static func createView() -> DAppListViewProtocol? {
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let sharedQueue = OperationManagerFacade.sharedDefaultQueue

        let phishingSiteRepository = SubstrateRepositoryFactory().createPhishingSitesRepository()
        let phishingSyncService = PhishingSitesSyncService(
            url: ApplicationConfig.shared.phishingDAppsURL,
            operationFactory: GitHubOperationFactory(),
            operationQueue: sharedQueue,
            repository: phishingSiteRepository
        )

        let logger = Logger.shared

        let favoritesFactory = DAppLocalSubscriptionFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationQueue: sharedQueue,
            logger: logger
        )

        let favoritesMapper = DAppFavoriteMapper()
        let favoritesRepository = UserDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(favoritesMapper)
        )

        let interactor = DAppListInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            dAppProvider: dAppProvider,
            phishingSyncService: phishingSyncService,
            dappsLocalSubscriptionFactory: favoritesFactory,
            dappsFavoriteRepository: AnyDataProviderRepository(favoritesRepository),
            operationQueue: sharedQueue,
            logger: logger
        )

        let wireframe = DAppListWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppListViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = DAppListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
