import Foundation
import SoraFoundation

struct DAppBrowserViewFactory {
    static func createView(for userInput: String) -> DAppBrowserViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let interactor = DAppBrowserInteractor(
            userInput: userInput,
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
