import Foundation
import Keystore_iOS
import Foundation_iOS

struct CloudBackupAddWalletViewFactory {
    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let wireframe = CloudBackupAddWalletWireframe()

        return createView(with: wireframe)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.CloudBackupAddWalletWireframe()

        return createView(with: wireframe)
    }

    private static func createView(
        with wireframe: CloudBackupAddWalletWireframeProtocol
    ) -> UsernameSetupViewProtocol? {
        let interactor = createInteractor()

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
            walletRequestFactory: WalletCreationRequestFactory(),
            walletOperationFactory: walletOperationFactory,
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
