import Foundation
import SoraFoundation
import Operation_iOS

struct DAppListViewFactory {
    static func createView(
        walletNotificationService: WalletNotificationServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol
    ) -> DAppListViewProtocol? {
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

        let favoritesRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createFavoriteDAppsRepository()

        let interactor = DAppListInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            dAppProvider: dAppProvider,
            phishingSyncService: phishingSyncService,
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: AnyDataProviderRepository(favoritesRepository),
            walletNotificationService: walletNotificationService,
            operationQueue: sharedQueue,
            logger: logger
        )

        let wireframe = DAppListWireframe(proxySyncService: proxySyncService)

        let browserTabManager = DAppBrowserTabManager.shared

        let newTabRouter = DAppBrowserNewTabRouter(
            tabManager: browserTabManager,
            operationQueue: sharedQueue,
            wireframe: DAppBrowserNewStackWireframe()
        )

        let localizationManager = LocalizationManager.shared

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            newTabRouter: newTabRouter,
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
