import Foundation
import SoraFoundation
import SoraUI

struct BackupAttentionViewFactory {
    static func createView(with metaAccount: MetaAccountModel) -> BackupAttentionViewProtocol? {
        let wireframe = BackupAttentionWireframe(metaAccount: metaAccount)

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
