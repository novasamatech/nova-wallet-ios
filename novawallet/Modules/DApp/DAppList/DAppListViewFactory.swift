import Foundation
import Foundation_iOS
import Operation_iOS

struct DAppListViewFactory {
    static func createView(
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> DAppListViewProtocol? {
        let interactor = createInteractor(walletNotificationService: walletNotificationService)

        let wireframe = DAppListWireframe(delegatedAccountSyncService: delegatedAccountSyncService)

        let localizationManager = LocalizationManager.shared

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initialWallet: SelectedWalletSettings.shared.value,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: .dApps,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
        ) else {
            return nil
        }

        let view = DAppListViewController(
            presenter: presenter,
            bannersViewProvider: bannersModule,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        walletNotificationService: WalletNotificationServiceProtocol
    ) -> DAppListInteractor {
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
            logger: logger
        )

        return interactor
    }
}
