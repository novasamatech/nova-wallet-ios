import SoraKeystore
import RobinHood
import FirebaseCore
import FirebaseFirestore

protocol Web3AlertsSyncServiceFactoryProtocol {
    func createService() -> Web3AlertsSyncServiceProtocol
}

final class Web3AlertsSyncServiceFactory: Web3AlertsSyncServiceFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue

    static var shared: Web3AlertsSyncServiceFactory = .init(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    init(
        storageFacade: StorageFacadeProtocol,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        operationQueue: OperationQueue
    ) {
        self.storageFacade = storageFacade
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
    }

    func createService() -> Web3AlertsSyncServiceProtocol {
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(Web3AlertSettingsMapper()))

        let service = Web3AlertsSyncService(
            repository: AnyDataProviderRepository(repository),
            settingsManager: settingsManager,
            operationQueue: operationQueue
        )

        return service
    }
}
