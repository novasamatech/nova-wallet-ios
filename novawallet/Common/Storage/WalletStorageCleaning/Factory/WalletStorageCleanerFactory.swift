import Foundation
import Operation_iOS

enum WalletStorageCleanerFactory {
    static func createWalletStorageCleaner(using operationQueue: OperationQueue) -> WalletStorageCleaning {
        let removedBrowserStateCleaner = createRemovedWalletBrowserStateCleaner(
            using: operationQueue
        )
        let removedDAppSettingsCleaner = createRemovedWalletDAppSettingsCleaner()
        let updatedBrowserStateCleaner = createUpdatedWalletBrowserStateCleaner(
            using: operationQueue
        )

        // Add every cleaner to the array
        // in the same order it should get called
        let cleaners = [
            removedBrowserStateCleaner,
            removedDAppSettingsCleaner,
            updatedBrowserStateCleaner
        ]

        let mainCleaner = WalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }

    // Remove

    private static func createRemovedWalletBrowserStateCleaner(
        using operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let browserTabManager = DAppBrowserTabManager.shared
        let webViewPoolEraser = WebViewPool.shared

        let browserStateCleaner = RemovedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }

    private static func createRemovedWalletDAppSettingsCleaner() -> WalletStorageCleaning {
        let mapper = DAppSettingsMapper()
        let storageFacade = UserDataStorageFacade.shared

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

    // Update

    private static func createUpdatedWalletBrowserStateCleaner(
        using operationQueue: OperationQueue
    ) -> WalletStorageCleaning {
        let browserTabManager = DAppBrowserTabManager.shared
        let webViewPoolEraser = WebViewPool.shared

        let browserStateCleaner = UpdatedWalletBrowserStateCleaner(
            browserTabManager: browserTabManager,
            webViewPoolEraser: webViewPoolEraser,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }
}
