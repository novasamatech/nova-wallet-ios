import Foundation

struct GovernanceRemoveVotesConfirmViewFactory {
    static func createView() -> GovernanceRemoveVotesConfirmViewProtocol? {
        let interactor = GovernanceRemoveVotesConfirmInteractor()
        let wireframe = GovernanceRemoveVotesConfirmWireframe()

        let presenter = GovernanceRemoveVotesConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceRemoveVotesConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}