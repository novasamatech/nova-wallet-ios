import Foundation

struct ReferendumVoteConfirmViewFactory {
    static func createView(
        for state: GovernanceLockState,
        newVote: ReferendumNewVote
    ) -> ReferendumVoteConfirmViewProtocol? {
        let interactor = ReferendumVoteConfirmInteractor()
        let wireframe = ReferendumVoteConfirmWireframe()

        let presenter = ReferendumVoteConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumVoteConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
