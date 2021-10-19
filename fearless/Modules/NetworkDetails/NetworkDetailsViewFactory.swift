import Foundation

struct NetworkDetailsViewFactory {
    static func createView() -> NetworkDetailsViewProtocol? {
        let interactor = NetworkDetailsInteractor()
        let wireframe = NetworkDetailsWireframe()

        let presenter = NetworkDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = NetworkDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
