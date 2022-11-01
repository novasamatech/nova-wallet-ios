import Foundation

struct GovernanceUnlockSetupViewFactory {
    static func createView() -> GovernanceUnlockSetupViewProtocol? {
        let interactor = GovernanceUnlockSetupInteractor()
        let wireframe = GovernanceUnlockSetupWireframe()

        let presenter = GovernanceUnlockSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceUnlockSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}