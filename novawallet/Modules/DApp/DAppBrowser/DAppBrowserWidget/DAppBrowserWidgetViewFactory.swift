import Foundation
import Foundation_iOS

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetViewProtocol? {
        let storageFacade = UserDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = DAppBrowserWidgetInteractor(
            tabManager: DAppBrowserTabManager.shared,
            selectedWalletSettings: SelectedWalletSettings.shared,
            operationQueue: operationQueue,
            logger: logger
        )

        let wireframe = DAppBrowserWidgetWireframe()

        let viewModelFactory = DAppBrowserWidgetViewModelFactory(
            dAppIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppBrowserWidgetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            browserTabsViewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let webViewPool = WebViewPool.shared

        let view = DAppBrowserWidgetViewController(
            presenter: presenter,
            webViewPoolEraser: webViewPool
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
