import Foundation

struct SwipeGovReferendumDetailsViewFactory {
    static func createView() -> SwipeGovReferendumDetailsViewProtocol? {
        let interactor = SwipeGovReferendumDetailsInteractor()
        let wireframe = SwipeGovReferendumDetailsWireframe()

        let presenter = SwipeGovReferendumDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = SwipeGovReferendumDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}