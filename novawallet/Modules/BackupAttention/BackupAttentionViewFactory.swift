import Foundation

struct BackupAttentionViewFactory {
    static func createView() -> BackupAttentionViewProtocol? {
        let interactor = BackupAttentionInteractor()
        let wireframe = BackupAttentionWireframe()

        let presenter = BackupAttentionPresenter(interactor: interactor, wireframe: wireframe)

        let view = BackupAttentionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}