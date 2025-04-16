import Foundation
import Foundation_iOS
import Keystore_iOS
import UIKit_iOS

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

        let checkboxListViewModelFactory = CheckboxListViewModelFactory(localizationManager: LocalizationManager.shared)

        let presenter = BackupAttentionPresenter(
            wireframe: wireframe,
            interactor: interactor,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
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
