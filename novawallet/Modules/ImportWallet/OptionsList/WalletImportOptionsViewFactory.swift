import Foundation

struct WalletImportOptionsViewFactory {
    static func createView() -> WalletImportOptionsViewProtocol? {
        let interactor = WalletImportOptionsInteractor()
        let wireframe = WalletImportOptionsWireframe()

        let presenter = WalletImportOptionsPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletImportOptionsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
