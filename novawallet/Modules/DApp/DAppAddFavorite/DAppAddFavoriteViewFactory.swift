import Foundation
import Foundation_iOS

struct DAppAddFavoriteViewFactory {
    static func createView(for browserPage: DAppBrowserPage) -> DAppAddFavoriteViewProtocol? {
        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createFavoriteDAppsRepository()

        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let interactor = DAppAddFavoriteInteractor(
            browserPage: browserPage,
            dAppProvider: dAppProvider,
            dAppsFavoriteRepository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = DAppAddFavoriteWireframe()
        let localizationManager = LocalizationManager.shared
        let iconViewModelFactory = DAppIconViewModelFactory()

        let presenter = DAppAddFavoritePresenter(
            interactor: interactor,
            wireframe: wireframe,
            iconViewModelFactory: iconViewModelFactory,
            localizationManager: localizationManager
        )

        let view = DAppAddFavoriteViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
