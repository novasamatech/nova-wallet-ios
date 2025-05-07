import Foundation

struct PayRootViewFactory {
    static func createView() -> PayRootViewProtocol? {
        let interactor = PayRootInteractor()
        let wireframe = PayRootWireframe()

        let presenter = PayRootPresenter(interactor: interactor, wireframe: wireframe)

        let view = PayRootViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
