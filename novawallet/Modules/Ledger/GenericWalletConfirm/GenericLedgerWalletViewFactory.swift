import Foundation

struct GenericLedgerWalletViewFactory {
    static func createView() -> GenericLedgerWalletViewProtocol? {
        let interactor = GenericLedgerWalletInteractor()
        let wireframe = GenericLedgerWalletWireframe()

        let presenter = GenericLedgerWalletPresenter(interactor: interactor, wireframe: wireframe)

        let view = GenericLedgerWalletViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
