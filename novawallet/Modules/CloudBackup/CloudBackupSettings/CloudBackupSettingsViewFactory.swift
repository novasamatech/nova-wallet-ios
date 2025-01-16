import Foundation
import Foundation_iOS
import Keystore_iOS

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
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFactory = ICloudBackupServiceFactory()

        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: operationQueue
        )

        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let secretsWalletRepository = repositoryFactory.createMetaAccountRepository(
            for: NSPredicate.onlySecretsWallets,
            sortDescriptors: []
        )

        let interactor = CloudBackupSettingsInteractor(
            cloudBackupSyncMediator: CloudBackupSyncMediatorFacade.sharedMediator,
            cloudBackupServiceFacade: serviceFacade,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: Keychain()
            ),
            secretsWalletRepository: secretsWalletRepository,
            operationQueue: OperationManagerFacade.cloudBackupQueue
        )

        return interactor
    }
}
