import Foundation

struct BackupMnemonicCardViewFactory {
    static func createView() -> BackupMnemonicCardViewProtocol? {
        let interactor = BackupMnemonicCardInteractor()
        let wireframe = BackupMnemonicCardWireframe()

        let presenter = BackupMnemonicCardPresenter(interactor: interactor, wireframe: wireframe)

        let view = BackupMnemonicCardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
