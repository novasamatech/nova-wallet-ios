import Foundation

final class WalletStorageCleanerFactory {
    static func createWalletStorageCleaner(using operationQueue: OperationQueue) -> WalletStorageCleaning {
        let browserStateCleaner = createBrowserStateCleaner(using: operationQueue)

        // Add every cleaner to the array
        // in the same order it should get called
        let cleaners = [
            browserStateCleaner
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
}
