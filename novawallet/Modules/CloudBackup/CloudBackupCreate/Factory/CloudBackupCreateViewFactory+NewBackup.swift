import Foundation_iOS
import Keystore_iOS

extension CloudBackupCreateViewFactory {
    static func createViewForNewBackup(
        from walletName: String
    ) -> CloudBackupCreateViewProtocol? {
        let flow = CloudBackupSetupPasswordFlow.newBackup

        let wireframe = CloudBackupCreateWireframe(walletName: walletName)

        let presenter = CloudBackupCreatePasswordPresenter(
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(flow: flow),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    static func createConfirmViewForNewBackup(
        from walletName: String,
        passwordToConfirm: String
    ) -> CloudBackupCreateViewProtocol? {
        let flow = CloudBackupSetupPasswordFlow.confirmPassword

        let interactor = createNewBackupInteractor(for: walletName)
        let wireframe = CloudBackupCreateConfirmWireframe()

        let presenter = CloudBackupConfirmPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(flow: flow),
            passwordValidator: CloudBackupPasswordValidator(),
            passwordToConfirm: passwordToConfirm,
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createNewBackupInteractor(for walletName: String) -> CloudBackupCreateInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()

        let keychain = Keychain()

        return .init(
            walletName: walletName,
            cloudBackupFacade: serviceFacade,
            walletRequestFactory: WalletCreationRequestFactory(),
            walletSettings: SelectedWalletSettings.shared,
            persistentKeystore: keychain,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: keychain
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
