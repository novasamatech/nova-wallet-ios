import Foundation
import Foundation_iOS
import Operation_iOS

struct DAppFavoritesViewFactory {
    static func createView() -> DAppFavoritesViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let favoritesRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createFavoriteDAppsRepository()

        let interactor = DAppFavoritesInteractor(
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: AnyDataProviderRepository(favoritesRepository),
            dAppProvider: dAppProvider,
            operationQueue: operationQueue,
            logger: logger
        )

        let wireframe = DAppFavoritesWireframe()

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let wallet: MetaAccountModel = SelectedWalletSettings.shared.value

        let presenter = DAppFavoritesPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            metaId: wallet.metaId,
            localizationManager: localizationManager,
            logger: logger
        )

        let view = DAppFavoritesViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
