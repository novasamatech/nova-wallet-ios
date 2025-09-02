import Foundation
@testable import novawallet
import Operation_iOS

extension WalletStorageCleanerFactory {
    static func createTestCleaner(
        operationQueue: OperationQueue,
        storageFacade: UserDataStorageTestFacade
    ) -> WalletStorageCleaning {
        let dAppSettingsCleaner = createDAppSettingsCleaner(storageFacade: storageFacade)

        let cleaners = [
            dAppSettingsCleaner
        ]

        let mainCleaner = WalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }
    
    private static func createDAppSettingsCleaner(storageFacade: StorageFacadeProtocol) -> WalletStorageCleaning {
        let mapper = DAppSettingsMapper()

        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let authorizedDAppRepository = AnyDataProviderRepository(repository)
        
        let dappSettingsCleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: authorizedDAppRepository
        )
        
        return dappSettingsCleaner
    }
}
