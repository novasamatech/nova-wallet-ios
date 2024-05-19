import Foundation
import SoraFoundation
import SoraUI

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
