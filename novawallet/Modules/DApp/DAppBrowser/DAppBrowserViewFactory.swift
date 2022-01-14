import Foundation
import SoraFoundation

struct DAppBrowserViewFactory {
    static func createView(for userQuery: DAppSearchResult) -> DAppBrowserViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let interactor = DAppBrowserInteractor(
            userQuery: userQuery,
            wallet: SelectedWalletSettings.shared.value,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: logger
        )

        let wireframe = DAppBrowserWireframe()

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )

        let view = DAppBrowserViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
