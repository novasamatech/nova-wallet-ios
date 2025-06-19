import Foundation

struct ParitySignerUpdateWalletViewFactory {
    static func createView() -> ParitySignerUpdateWalletViewProtocol? {
        let interactor = ParitySignerUpdateWalletInteractor()
        let wireframe = ParitySignerUpdateWalletWireframe()

        let presenter = ParitySignerUpdateWalletPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParitySignerUpdateWalletViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}