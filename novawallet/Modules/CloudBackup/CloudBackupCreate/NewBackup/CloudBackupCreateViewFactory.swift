import Foundation
import SoraKeystore
import SoraFoundation

struct CloudBackupCreateViewFactory {
    static func createViewForNewBackup(from walletName: String) -> CloudBackupCreateViewProtocol? {
        let interactor = createNewBackupInteractor(for: walletName)
        let wireframe = CloudBackupCreateWireframe()

        let presenter = CloudBackupCreatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: .newBackup,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createViewForUpdatePassword(for password: String) -> CloudBackupCreateViewProtocol? {
        let interactor = createPasswordChangeInteractor(for: password)
        let wireframe = CloudBackupUpdatePasswordWireframe()

        let presenter = CloudBackupCreatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: .changePassword,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createViewForEnableBackup() -> CloudBackupCreateViewProtocol? {
        let interactor = createEnableBackupInteractor()
        let wireframe = CloudBackupEnablePasswordWireframe()

        let presenter = CloudBackupCreatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: .newBackup,
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

    private static func createPasswordChangeInteractor(for password: String) -> CloudBackupUpdatePasswordInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()
        return CloudBackupUpdatePasswordInteractor(
            oldPassword: password,
            serviceFacade: serviceFacade,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: Keychain()
            )
        )
    }

    private static func createEnableBackupInteractor() -> CloudBackupEnablePasswordInteractor {
        let keystore = Keychain()

        let syncMetadataManager = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: keystore
        )

        return CloudBackupEnablePasswordInteractor(
            repositoryFactory: AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared),
            cloudBackupFacade: CloudBackupServiceFacade.createFacade(),
            syncMetadataManager: syncMetadataManager,
            keystore: keystore,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
