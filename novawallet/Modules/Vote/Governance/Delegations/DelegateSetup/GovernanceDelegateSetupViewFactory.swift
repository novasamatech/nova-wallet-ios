import Foundation

struct GovernanceDelegateSetupViewFactory {
    static func createView() -> GovernanceDelegateSetupViewProtocol? {
        let interactor = GovernanceDelegateSetupInteractor()
        let wireframe = GovernanceDelegateSetupWireframe()

        let presenter = GovernanceDelegateSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceDelegateSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
