import Foundation

struct SwipeGovVotingConfirmViewFactory {
    static func createView() -> SwipeGovVotingConfirmViewProtocol? {
        let interactor = SwipeGovVotingConfirmInteractor()
        let wireframe = SwipeGovVotingConfirmWireframe()

        let presenter = SwipeGovVotingConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = SwipeGovVotingConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
