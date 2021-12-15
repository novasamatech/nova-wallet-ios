import Foundation

struct DAppBrowserViewFactory {
    static func createView(for _: String) -> DAppBrowserViewProtocol? {
        let interactor = DAppBrowserInteractor()
        let wireframe = DAppBrowserWireframe()

        let presenter = DAppBrowserPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppBrowserViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
