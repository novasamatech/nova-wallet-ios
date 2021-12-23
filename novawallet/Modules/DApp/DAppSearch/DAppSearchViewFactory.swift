import Foundation

struct DAppSearchViewFactory {
    static func createView() -> DAppSearchViewProtocol? {
        let interactor = DAppSearchInteractor()
        let wireframe = DAppSearchWireframe()

        let presenter = DAppSearchPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppSearchViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
