import Foundation
import SoraFoundation
import SoraUI

struct BackupAttentionViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) -> BackupAttentionViewProtocol? {
        let wireframe = BackupAttentionWireframe(
            metaAccount: metaAccount,
            chain: chain
        )

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
