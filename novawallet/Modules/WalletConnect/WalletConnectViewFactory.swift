import Foundation

struct WalletConnectViewFactory {
    static func createView() -> WalletConnectViewProtocol? {
        let interactor = WalletConnectInteractor()
        let wireframe = WalletConnectWireframe()

        let presenter = WalletConnectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = WalletConnectViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
