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
    func createTabsCleaningWrapper(
        for changesProvider: @escaping () throws -> [DataProviderChange<ManagedMetaAccountModel>]
    ) -> CompoundOperationWrapper<Set<UUID>> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let metaIds = try changesProvider()
                .filter { $0.isDeletion }
                .map(\.identifier)

            return browserTabManager.removeAllWrapper(for: Set(metaIds))
        }
    }

    func createWebViewCleaningOperation(
        dependingOn tabIdsOperation: BaseOperation<Set<UUID>>
    ) -> ClosureOperation<Void> {
        ClosureOperation { [weak self] in
            let tabIds = try tabIdsOperation.extractNoCancellableResultData()

            tabIds.forEach { tabId in
                DispatchQueue.main.async {
                    self?.webViewPoolEraser.removeWebView(for: tabId)
                }
            }
        }
    }
}

// MARK: WalletStorageCleaning

extension RemovedWalletBrowserStateCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let tabsCleaningWrapper = createTabsCleaningWrapper(for: providers.changesProvider)

        let webViewPoolCleaningOperation = createWebViewCleaningOperation(
            dependingOn: tabsCleaningWrapper.targetOperation
        )

        webViewPoolCleaningOperation.addDependency(tabsCleaningWrapper.targetOperation)

        return tabsCleaningWrapper.insertingTail(operation: webViewPoolCleaningOperation)
    }
}
