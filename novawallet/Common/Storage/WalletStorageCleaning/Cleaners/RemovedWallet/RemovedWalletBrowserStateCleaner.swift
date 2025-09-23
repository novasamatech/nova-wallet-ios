import Foundation
import Operation_iOS

final class RemovedWalletBrowserStateCleaner {
    private let browserTabManager: DAppBrowserTabManagerProtocol
    private let webViewPoolEraser: WebViewPoolEraserProtocol
    private let operationQueue: OperationQueue

    init(
        browserTabManager: DAppBrowserTabManagerProtocol,
        webViewPoolEraser: WebViewPoolEraserProtocol,
        operationQueue: OperationQueue
    ) {
        self.browserTabManager = browserTabManager
        self.webViewPoolEraser = webViewPoolEraser
        self.operationQueue = operationQueue
    }
}

// MARK: Private

private extension RemovedWalletBrowserStateCleaner {
    func createWebViewCleaningOperation(
        dependingOn tabIdsOperation: BaseOperation<Set<UUID>>
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { [weak self] completion in
            let tabIds = try tabIdsOperation.extractNoCancellableResultData()

            DispatchQueue.main.async {
                tabIds.forEach { tabId in
                    self?.webViewPoolEraser.removeWebView(for: tabId)
                }

                completion(.success(()))
            }
        }
    }
}

// MARK: WalletStorageCleaning

extension RemovedWalletBrowserStateCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let metaIds = providers.changesProvider()
            .filter { $0.isDeletion }
            .map(\.identifier)

        guard !metaIds.isEmpty else {
            return .createWithResult(())
        }

        let tabsCleaningWrapper = browserTabManager.removeAllWrapper(for: Set(metaIds))

        let webViewPoolCleaningOperation = createWebViewCleaningOperation(
            dependingOn: tabsCleaningWrapper.targetOperation
        )

        webViewPoolCleaningOperation.addDependency(tabsCleaningWrapper.targetOperation)

        return tabsCleaningWrapper.insertingTail(operation: webViewPoolCleaningOperation)
    }
}
