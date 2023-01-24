import Foundation

struct GovernanceDelegateInfoViewFactory {
    static func createView(for _: GovernanceDelegateLocal) -> GovernanceDelegateInfoViewProtocol? {
        let interactor = GovernanceDelegateInfoInteractor()
        let wireframe = GovernanceDelegateInfoWireframe()

        let presenter = GovernanceDelegateInfoPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceDelegateInfoViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
