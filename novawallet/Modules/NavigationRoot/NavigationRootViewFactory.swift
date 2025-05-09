import Foundation

struct NavigationRootViewFactory {
    static func createView(with child: ScrollViewHostControlling) -> NavigationRootViewProtocol? {
        let interactor = NavigationRootInteractor()
        let wireframe = NavigationRootWireframe()

        let presenter = NavigationRootPresenter(interactor: interactor, wireframe: wireframe)

        let view = NavigationRootViewController(scrollHost: child, presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
