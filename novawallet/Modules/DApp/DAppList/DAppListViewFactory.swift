import Foundation
import SoraFoundation

struct DAppListViewFactory {
    static func createView() -> DAppListViewProtocol? {
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let interactor = DAppListInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            dAppProvider: dAppProvider
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
