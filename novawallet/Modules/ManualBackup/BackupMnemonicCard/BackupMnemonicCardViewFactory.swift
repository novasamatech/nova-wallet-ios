import Foundation
import SoraKeystore
import SoraFoundation
import SoraUI

struct BackupMnemonicCardViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) -> BackupMnemonicCardViewProtocol? {
        let keychain = Keychain()

        let interactor = BackupMnemonicCardInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = BackupMnemonicCardWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: LocalizationManager.shared)

        let presenter = BackupMnemonicCardPresenter(
            interactor: interactor,
            wireframe: wireframe,
            metaAccount: metaAccount,
            chain: chain,
            networkViewModelFactory: networkViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = BackupMnemonicCardViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
