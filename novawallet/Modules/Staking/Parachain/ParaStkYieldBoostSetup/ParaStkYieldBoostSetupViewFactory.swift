import Foundation

struct ParaStkYieldBoostSetupViewFactory {
    static func createView() -> ParaStkYieldBoostSetupViewProtocol? {
        let interactor = ParaStkYieldBoostSetupInteractor()
        let wireframe = ParaStkYieldBoostSetupWireframe()

        let presenter = ParaStkYieldBoostSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParaStkYieldBoostSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}