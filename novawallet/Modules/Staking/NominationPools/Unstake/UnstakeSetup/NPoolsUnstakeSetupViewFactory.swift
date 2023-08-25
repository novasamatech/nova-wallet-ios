import Foundation

struct NPoolsUnstakeSetupViewFactory {
    static func createView() -> NPoolsUnstakeSetupViewProtocol? {
        let interactor = NPoolsUnstakeSetupInteractor()
        let wireframe = NPoolsUnstakeSetupWireframe()

        let presenter = NPoolsUnstakeSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = NPoolsUnstakeSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}