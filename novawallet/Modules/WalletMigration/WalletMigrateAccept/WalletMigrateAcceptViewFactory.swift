import Foundation

struct WalletMigrateAcceptViewFactory {
    static func createView() -> WalletMigrateAcceptViewProtocol? {
        let interactor = WalletMigrateAcceptInteractor()
        let wireframe = WalletMigrateAcceptWireframe()

        let presenter = WalletMigrateAcceptPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletMigrateAcceptViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}