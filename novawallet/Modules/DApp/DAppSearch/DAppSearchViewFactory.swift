import Foundation
import SoraFoundation

struct DAppSearchViewFactory {
    static func createView(
        with initialQuery: String?,
        delegate: DAppSearchDelegate
    ) -> DAppSearchViewProtocol? {
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let interactor = DAppSearchInteractor(
            dAppProvider: dAppProvider,
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            logger: Logger.shared
        )

        let wireframe = DAppSearchWireframe()

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory()
        )

        let presenter = DAppSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            initialQuery: initialQuery,
            delegate: delegate,
            applicationConfig: ApplicationConfig.shared,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DAppSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
