import Foundation

struct GovernanceDelegateConfirmViewFactory {
    static func createView() -> GovernanceDelegateConfirmViewProtocol? {
        let interactor = GovernanceDelegateConfirmInteractor()
        let wireframe = GovernanceDelegateConfirmWireframe()

        let presenter = GovernanceDelegateConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceDelegateConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}