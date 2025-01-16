import Foundation
import Foundation_iOS

struct DAppSearchViewFactory {
    static func createView(
        with initialQuery: String? = nil,
        selectedCategoryId: String? = nil,
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
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            initialQuery: initialQuery,
            selectedCategoryId: selectedCategoryId,
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
