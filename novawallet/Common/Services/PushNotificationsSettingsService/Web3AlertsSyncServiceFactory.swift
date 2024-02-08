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
    private var service: Web3AlertsSyncServiceProtocol?

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
        if let service = service {
            return service
        }

        FirebaseApp.configure()
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(Web3AlertSettingsMapper()))

        let service = Web3AlertsSyncService(
            repository: AnyDataProviderRepository(repository),
            settingsManager: settingsManager,
            operationQueue: operationQueue
        )
        self.service = service

        return service
    }
}
