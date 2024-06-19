import Foundation

struct NetworkManageNodeViewFactory {
    static func createView() -> NetworkManageNodeViewProtocol? {
        let interactor = NetworkManageNodeInteractor()
        let wireframe = NetworkManageNodeWireframe()

        let presenter = NetworkManageNodePresenter(interactor: interactor, wireframe: wireframe)

        let view = NetworkManageNodeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}