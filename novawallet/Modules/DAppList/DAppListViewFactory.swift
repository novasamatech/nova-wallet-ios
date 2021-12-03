import Foundation

struct DAppListViewFactory {
    static func createView() -> DAppListViewProtocol? {
        let interactor = DAppListInteractor()
        let wireframe = DAppListWireframe()

        let presenter = DAppListPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}