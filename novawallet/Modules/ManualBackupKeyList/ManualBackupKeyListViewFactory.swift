import Foundation

struct ManualBackupKeyListViewFactory {
    static func createView() -> ManualBackupKeyListViewProtocol? {
        let interactor = ManualBackupKeyListInteractor()
        let wireframe = ManualBackupKeyListWireframe()

        let presenter = ManualBackupKeyListPresenter(interactor: interactor, wireframe: wireframe)

        let view = ManualBackupKeyListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}