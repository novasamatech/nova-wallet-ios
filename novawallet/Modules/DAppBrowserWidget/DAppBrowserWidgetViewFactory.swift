import Foundation

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetViewProtocol? {
        let interactor = DAppBrowserWidgetInteractor()
        let wireframe = DAppBrowserWidgetWireframe()

        let presenter = DAppBrowserWidgetPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppBrowserWidgetViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}