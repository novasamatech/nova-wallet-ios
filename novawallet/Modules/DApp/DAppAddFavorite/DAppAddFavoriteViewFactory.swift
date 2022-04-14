import Foundation

struct DAppAddFavoriteViewFactory {
    static func createView() -> DAppAddFavoriteViewProtocol? {
        let interactor = DAppAddFavoriteInteractor()
        let wireframe = DAppAddFavoriteWireframe()

        let presenter = DAppAddFavoritePresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppAddFavoriteViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}