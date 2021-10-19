import Foundation

struct NetworkDetailsViewFactory {
    static func createView(chainModel: ChainModel) -> NetworkDetailsViewProtocol? {
        let interactor = NetworkDetailsInteractor()
        let wireframe = NetworkDetailsWireframe()

        let presenter = NetworkDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainModel: chainModel
        )

        let view = NetworkDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
