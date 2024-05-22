import Foundation
import SoraFoundation
import SoraKeystore

struct CloudBackupSettingsViewFactory {
    static func createView() -> CloudBackupSettingsViewProtocol? {
        let interactor = createInteractor()
        let wireframe = CloudBackupSettingsWireframe()

        let presenter = CloudBackupSettingsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: CloudBackupSettingsViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CloudBackupSettingsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> CloudBackupSettingsInteractor {
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: OperationManagerFacade.sharedDefaultQueue)
        let syncMetadataManaging = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )

        let walletsRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let syncFactory = CloudBackupSyncFactory(
            serviceFactory: serviceFactory,
            syncMetadataManaging: syncMetadataManaging,
            walletsRepositoryFactory: walletsRepositoryFactory,
            notificationCenter: NotificationCenter.default,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let syncFacade = CloudBackupSyncFacade(
            syncFactory: syncFactory,
            syncMetadataManager: syncMetadataManaging,
            fileManager: serviceFactory.createFileManager(),
            workingQueue: .global(),
            logger: Logger.shared
        )

        let walletsRepository = walletsRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let walletsUpdater = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: walletsRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let backupApplicationFactory = CloudBackupUpdateApplicationFactory(
            serviceFactory: serviceFactory,
            walletRepositoryFactory: walletsRepositoryFactory,
            walletsUpdater: walletsUpdater,
            keystore: Keychain(),
            syncMetadataManager: syncMetadataManaging,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            cloudBackupSyncFacade: syncFacade,
            cloudBackupApplicationFactory: backupApplicationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
