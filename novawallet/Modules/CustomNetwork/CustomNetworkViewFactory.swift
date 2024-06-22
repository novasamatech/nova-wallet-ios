import Foundation

struct CustomNetworkViewFactory {
    static func createView() -> CustomNetworkViewProtocol? {
        let interactor = CustomNetworkInteractor()
        let wireframe = CustomNetworkWireframe()

        let presenter = CustomNetworkPresenter(interactor: interactor, wireframe: wireframe)

        let view = CustomNetworkViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}