import Foundation
import SoraFoundation
import Operation_iOS

struct DAppListViewFactory {
    static func createView(
        walletNotificationService: WalletNotificationServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol
    ) -> DAppListViewProtocol? {
        let appConfig = ApplicationConfig.shared
        let dAppsUrl = appConfig.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let sharedQueue = OperationManagerFacade.sharedDefaultQueue

        let phishingSiteRepository = SubstrateRepositoryFactory().createPhishingSitesRepository()
        let phishingSyncService = PhishingSitesSyncService(
            url: appConfig.phishingDAppsURL,
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

        let localizationManager = LocalizationManager.shared

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
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
