import Foundation

struct ReferendumVoteSetupViewFactory {
    static func createView() -> ReferendumVoteSetupViewProtocol? {
        let interactor = ReferendumVoteSetupInteractor()
        let wireframe = ReferendumVoteSetupWireframe()

        let presenter = ReferendumVoteSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumVoteSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
