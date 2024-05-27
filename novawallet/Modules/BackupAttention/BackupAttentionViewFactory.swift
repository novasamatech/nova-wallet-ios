import Foundation
import SoraFoundation
import SoraKeystore
import SoraUI

struct BackupAttentionViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) -> BackupAttentionViewProtocol? {
        let keystore = Keychain()

        let wireframe = BackupAttentionWireframe(
            metaAccount: metaAccount,
            chain: chain
        )

        let interactor = BackupAttentionInteractor(
            keystore: keystore,
            metaAccount: metaAccount,
            chain: chain
        )

        let presenter = BackupAttentionPresenter(
            wireframe: wireframe,
            interactor: interactor,
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
