import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

final class ExportMnemonicViewFactory {
    static func createViewForMetaAccount(
        _ metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> AccountCreateViewProtocol? {
        let keychain = Keychain()

        let interactor = ExportMnemonicInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )

        let wireframe = ExportMnemonicWireframe()

        let localizationManager = LocalizationManager.shared

        let checkboxListViewModelFactory = CheckboxListViewModelFactory(localizationManager: localizationManager)
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let presenter = ExportMnemonicPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory
        )

        let view = AccountCreateViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
