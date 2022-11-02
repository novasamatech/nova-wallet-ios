import Foundation

struct GovernanceUnlockConfirmViewFactory {
    static func createView(for state: GovernanceSharedState) -> GovernanceUnlockConfirmViewProtocol? {
        let interactor = GovernanceUnlockConfirmInteractor()
        let wireframe = GovernanceUnlockConfirmWireframe()

        let presenter = GovernanceUnlockConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceUnlockConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
