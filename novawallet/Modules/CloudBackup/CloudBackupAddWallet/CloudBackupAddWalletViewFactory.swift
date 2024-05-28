import Foundation
import SoraKeystore
import SoraFoundation

struct CloudBackupAddWalletViewFactory {
    static func createView() -> UsernameSetupViewProtocol? {
        let interactor = createInteractor()
        let wireframe = CloudBackupAddWalletWireframe()

        let presenter = CloudBackupAddWalletPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = UserNameSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> CloudBackupAddWalletInteractor {
        let keystore = Keychain()
        let walletOperationFactory = MetaAccountOperationFactory(keystore: keystore)

        return CloudBackupAddWalletInteractor(
            walletOperationFactory: walletOperationFactory,
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
