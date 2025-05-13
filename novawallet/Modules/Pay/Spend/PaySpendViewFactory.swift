import Foundation

struct PaySpendViewFactory {
    static func createView() -> PaySpendViewProtocol? {
        let interactor = PaySpendInteractor()
        let wireframe = PaySpendWireframe()

        let presenter = PaySpendPresenter(interactor: interactor, wireframe: wireframe)

        let view = PaySpendViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
