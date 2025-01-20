import Foundation
import Operation_iOS

extension WalletStorageCleanerFactory {
    static func createUpdatedWalletStorageCleaner(using operationQueue: OperationQueue) -> WalletStorageCleaning {
        let browserStateCleaner = createBrowserStateCleaner(using: operationQueue)

        // Add every cleaner to the array
        // in the same order it should get called
        let cleaners = [
            browserStateCleaner
        ]

        let mainCleaner = WalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }

    private static func createBrowserStateCleaner(
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
