import Foundation
import SoraFoundation
import RobinHood

struct DAppAuthSettingsViewFactory {
    static func createView() -> DAppAuthSettingsViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let applicationConfig = ApplicationConfig.shared
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: applicationConfig.dAppsListURL
        )

        let authorizedRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAuthorizedDAppsRepository(for: wallet.metaId)

        let interactor = DAppAuthSettingsInteractor(
            wallet: wallet,
            dAppProvider: dAppProvider,
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            authorizedDAppRepository: authorizedRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = DAppAuthSettingsWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = DAppAuthSettingsPresenter(
            wallet: wallet,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppsAuthViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = DAppAuthSettingsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
