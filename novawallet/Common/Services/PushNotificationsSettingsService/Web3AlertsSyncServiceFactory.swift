import SoraKeystore
import RobinHood

protocol Web3AlertsSyncServiceFactoryProtocol {
    func createService() -> Web3AlertsSyncServiceProtocol
}

final class Web3AlertsSyncServiceFactory: Web3AlertsSyncServiceFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let settingsManager: SettingsManagerProtocol
    let operationQueue: OperationQueue

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
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> = storageFacade.createRepository()

        return Web3AlertsSyncService(
            repository: AnyDataProviderRepository(repository),
            settingsManager: settingsManager,
            operationQueue: operationQueue
        )
    }
}
