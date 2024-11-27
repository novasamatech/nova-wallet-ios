import Foundation

struct NovaMainAppContainerViewFactory {
    static func createView() -> NovaMainAppContainerViewProtocol? {
        let interactor = NovaMainAppContainerInteractor()
        let wireframe = NovaMainAppContainerWireframe()

        let presenter = NovaMainAppContainerPresenter(interactor: interactor, wireframe: wireframe)

        let view = NovaMainAppContainerViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
