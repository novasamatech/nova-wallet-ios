import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class AccountExportPasswordViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> AccountExportPasswordViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let exportJsonWrapper = KeystoreExportWrapper(keystore: Keychain())

        let interactor = AccountExportPasswordInteractor(
            metaAccount: metaAccount,
            chain: chain,
            exportJsonWrapper: exportJsonWrapper,
            operationManager: OperationManagerFacade.sharedManager
        )

        let wireframe = AccountExportPasswordWireframe()

        let presenter = AccountExportPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = AccountExportPasswordViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
