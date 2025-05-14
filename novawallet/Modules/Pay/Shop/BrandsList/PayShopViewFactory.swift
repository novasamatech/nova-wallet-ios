import Foundation

struct PayShopViewFactory {
    static func createView() -> PayShopViewProtocol? {
        let interactor = PayShopInteractor()
        let wireframe = PayShopWireframe()

        let presenter = PayShopPresenter(interactor: interactor, wireframe: wireframe)

        let view = PayShopViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
