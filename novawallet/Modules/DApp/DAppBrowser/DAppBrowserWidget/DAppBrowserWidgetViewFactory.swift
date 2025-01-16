import Foundation
import Foundation_iOS

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetViewProtocol? {
        let interactor = DAppBrowserWidgetInteractor(tabManager: DAppBrowserTabManager.shared)

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
