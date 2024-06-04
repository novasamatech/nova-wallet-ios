import Foundation
import SoraFoundation
import SoraKeystore

struct ImportCloudPasswordViewFactory {
    static func createImportView() -> ImportCloudPasswordViewProtocol? {
        let interactor = createImportInteractor()
        let wireframe = ImportCloudPasswordWireframe()

        let presenter = ImportCloudPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = ImportCloudPasswordViewController(
            presenter: presenter,
            flow: .importBackup,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createSetPasswordView() -> ImportCloudPasswordViewProtocol? {
        let interactor = createSetPasswordInteractor()
        let wireframe = CloudBackupEnterPasswordSetWireframe()

        let presenter = ImportCloudPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = ImportCloudPasswordViewController(
            presenter: presenter,
            flow: .enterPassword,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createChangePasswordView() -> ImportCloudPasswordViewProtocol? {
        let interactor = createChangePasswordInteractor()
        let wireframe = CloudBackupEnterPasswordCheckWireframe()

        let presenter = ImportCloudPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = ImportCloudPasswordViewController(
            presenter: presenter,
            flow: .changePassword,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createImportInteractor() -> ImportCloudPasswordInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let keystore = Keychain()

        return .init(
            cloudBackupFacade: serviceFacade,
            walletRepository: walletRepository,
            selectedWalletSettings: SelectedWalletSettings.shared,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: keystore
            ),
            keystore: keystore
        )
    }

    private static func createChangePasswordInteractor() -> BaseBackupEnterPasswordInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()

        let password = try? Keychain().fetchKey(for: KeystoreTagV2.cloudBackupPassword.rawValue)

        Logger.shared.info("Password: \(password.flatMap { String(data: $0, encoding: .utf8) })")

        return CloudBackupEnterPasswordCheckInteractor(
            cloudBackupSyncFacade: CloudBackupSyncMediatorFacade.sharedMediator.syncFacade,
            cloudBackupServiceFacade: serviceFacade
        )
    }

    private static func createSetPasswordInteractor() -> BaseBackupEnterPasswordInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()

        return CloudBackupEnterPasswordSetInteractor(
            cloudBackupSyncFacade: CloudBackupSyncMediatorFacade.sharedMediator.syncFacade,
            cloudBackupServiceFacade: serviceFacade,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: Keychain()
            )
        )
    }
}
