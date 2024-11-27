import Foundation

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetContainableView? {
        let interactor = DAppBrowserWidgetInteractor(
            tabManager: DAppBrowserTabManager.shared
        )
        let wireframe = DAppBrowserWidgetWireframe()

        let presenter = DAppBrowserWidgetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactory()
        )

        let view = DAppBrowserWidgetViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
