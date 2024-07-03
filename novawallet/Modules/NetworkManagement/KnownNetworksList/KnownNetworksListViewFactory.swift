import Foundation

struct KnownNetworksListViewFactory {
    static func createView() -> KnownNetworksListViewProtocol? {
        let interactor = KnownNetworksListInteractor()
        let wireframe = KnownNetworksListWireframe()

        let presenter = KnownNetworksListPresenter(interactor: interactor, wireframe: wireframe)

        let view = KnownNetworksListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}