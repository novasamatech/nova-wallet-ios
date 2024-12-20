import Foundation
import SoraFoundation

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetViewProtocol? {
        let interactor = DAppBrowserWidgetInteractor(
            tabManager: DAppBrowserTabManager.shared
        )

        let wireframe = DAppBrowserWidgetWireframe()

        let presenter = DAppBrowserWidgetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactory(),
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
