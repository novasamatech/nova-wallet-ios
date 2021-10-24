import Foundation

struct WalletListViewFactory {
    static func createView() -> WalletListViewProtocol? {
        let interactor = WalletListInteractor()
        let wireframe = WalletListWireframe()

        let presenter = WalletListPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}