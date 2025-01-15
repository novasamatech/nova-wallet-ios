import Foundation
import Operation_iOS

final class WalletStorageCleanerFactory {
    static func createWalletStorageCleaner(using operationQueue: OperationQueue) -> WalletStorageCleaning {
        let browserStateCleaner = createBrowserStateCleaner(using: operationQueue)
        let dAppSettingsCleaner = createDAppSettingsCleaner()

        // Add every cleaner to the array
        // in the same order it should get called
        let cleaners = [
            browserStateCleaner,
            dAppSettingsCleaner
        ]

        let mainCleaner = RemovedWalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }

    private static func createBrowserStateCleaner(
        using operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let browserTabManager = DAppBrowserTabManager.shared
        let webViewPoolEraser = WebViewPool.shared

        let browserStateCleaner = WalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }

    private static func createDAppSettingsCleaner() -> WalletStorageCleaning {
        let mapper = DAppSettingsMapper()
        let storageFacade = UserDataStorageFacade.shared

        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let authorizedDAppRepository = AnyDataProviderRepository(repository)

        let dappSettingsCleaner = DAppSettingsCleaner(authorizedDAppRepository: authorizedDAppRepository)

        return dappSettingsCleaner
    }
}
