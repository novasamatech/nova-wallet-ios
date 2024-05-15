import Foundation
import SoraFoundation

struct BackupAttentionViewFactory {
    static func createView() -> BackupAttentionViewProtocol? {
        let wireframe = BackupAttentionWireframe()

        let presenter = BackupAttentionPresenter(
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = BackupAttentionViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
