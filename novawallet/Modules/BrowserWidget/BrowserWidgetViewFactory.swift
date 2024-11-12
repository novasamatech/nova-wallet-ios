import Foundation

struct BrowserWidgetViewFactory {
    static func createView() -> BrowserWidgetContainableView? {
        let interactor = BrowserWidgetInteractor()
        let wireframe = BrowserWidgetWireframe()

        let presenter = BrowserWidgetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            browserTabsViewModelFactory: BrowserWidgetViewModelFactory()
        )

        let view = BrowserWidgetViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
