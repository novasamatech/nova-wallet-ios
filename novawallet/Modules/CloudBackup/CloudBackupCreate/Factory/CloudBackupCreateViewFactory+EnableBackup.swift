import Foundation_iOS
import Keystore_iOS

extension CloudBackupCreateViewFactory {
    static func createViewForEnableBackup() -> CloudBackupCreateViewProtocol? {
        let flow: CloudBackupSetupPasswordFlow = .newBackup

        let wireframe = CloudBackupEnablePasswordWireframe()

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

    static func createConfirmViewForEnableBackup(password: String) -> CloudBackupCreateViewProtocol? {
        let flow: CloudBackupSetupPasswordFlow = .confirmPassword

        let interactor = createEnableBackupInteractor()
        let wireframe = CloudBackupEnablePasswordConfirmWireframe()

        let presenter = CloudBackupConfirmPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(flow: flow),
            passwordValidator: CloudBackupPasswordValidator(),
            passwordToConfirm: password,
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
