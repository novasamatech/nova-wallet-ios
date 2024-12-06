import Foundation
import SoraFoundation
import Operation_iOS

struct DAppFavoritesViewFactory {
    static func createView() -> DAppFavoritesViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let favoritesRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createFavoriteDAppsRepository()

        let interactor = DAppFavoritesInteractor(
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: AnyDataProviderRepository(favoritesRepository),
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let wireframe = DAppFavoritesWireframe()

        let categoriesViewModelFactory = DAppCategoryViewModelFactory()
        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: categoriesViewModelFactory
        )

        let presenter = DAppFavoritesPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = DAppFavoritesViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
