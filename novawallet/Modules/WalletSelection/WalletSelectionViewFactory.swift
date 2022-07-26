import Foundation

struct WalletSelectionViewFactory {
    static func createView() -> WalletSelectionViewProtocol? {
        let interactor = WalletSelectionInteractor()
        let wireframe = WalletSelectionWireframe()

        let presenter = WalletSelectionPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletSelectionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}