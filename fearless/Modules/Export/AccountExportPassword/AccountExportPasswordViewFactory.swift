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

        let view = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = AccountExportPasswordPresenter(
            localizationManager: localizationManager
        )

        let exportJsonWrapper = KeystoreExportWrapper(keystore: Keychain())

        let interactor = AccountExportPasswordInteractor(
            metaAccount: metaAccount,
            chain: chain,
            exportJsonWrapper: exportJsonWrapper,
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = AccountExportPasswordWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
