import Foundation
import Operation_iOS

final class UpdatedWalletBrowserStateCleaner {
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

private extension UpdatedWalletBrowserStateCleaner {
    func createTransportCleaningWrapper(
        dependingOn tabIdsWrapper: CompoundOperationWrapper<Set<UUID>>
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let tabIds = try tabIdsWrapper.targetOperation.extractNoCancellableResultData()
            let cleaningOperation = browserTabManager.cleanTransport(for: tabIds)

            return CompoundOperationWrapper(targetOperation: cleaningOperation)
        }
    }

    func createWebViewCleaningOperation(
        dependingOn tabIdsWrapper: CompoundOperationWrapper<Set<UUID>>
    ) -> ClosureOperation<Void> {
        ClosureOperation { [weak self] in
            let tabIds = try tabIdsWrapper.targetOperation.extractNoCancellableResultData()

            tabIds.forEach { tabId in
                DispatchQueue.main.async {
                    self?.webViewPoolEraser.removeWebView(for: tabId)
                }
            }
        }
    }

    func createTabIdsWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Set<UUID>> {
        let tabsWrapper = createTabsWrapper(using: providers)

        let mappingOperation = ClosureOperation<Set<UUID>> {
            let tabIds = try tabsWrapper.targetOperation
                .extractNoCancellableResultData()
                .map(\.uuid)

            return Set(tabIds)
        }

        mappingOperation.addDependency(tabsWrapper.targetOperation)

        return tabsWrapper.insertingTail(operation: mappingOperation)
    }

    func createTabsWrapper(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let metaIdsOperation = createMetaIdsOperation(using: providers)

        let tabsWrapper: CompoundOperationWrapper<[DAppBrowserTab]> = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let metaIds = try metaIdsOperation.extractNoCancellableResultData()

            return browserTabManager.getAllTabs(for: metaIds)
        }

        tabsWrapper.addDependency(operations: [metaIdsOperation])

        return tabsWrapper.insertingHead(operations: [metaIdsOperation])
    }

    func createMetaIdsOperation(
        using providers: WalletStorageCleaningProviders
    ) -> ClosureOperation<Set<MetaAccountModel.Id>> {
        ClosureOperation {
            let walletsBeforeChanges = try providers.walletsBeforeChangesProvider()
            let updatedWallets = try providers.changesProvider()
                .map(\.item)

            let cleanTabsWalletIds = updatedWallets
                .filter {
                    guard
                        let updatedWallet = $0?.info,
                        let walletBeforeChange = walletsBeforeChanges[updatedWallet.metaId]?.info
                    else {
                        return false
                    }

                    return walletBeforeChange.chainAccounts != updatedWallet.chainAccounts
                }.compactMap { $0?.info.metaId }

            return Set(cleanTabsWalletIds)
        }
    }
}

// MARK: WalletStorageCleaning

extension UpdatedWalletBrowserStateCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let tabIdsWrapper = createTabIdsWrapper(using: providers)

        let webViewPoolCleaningOperation = createWebViewCleaningOperation(
            dependingOn: tabIdsWrapper
        )
        let transportsCleaningWrapper = createTransportCleaningWrapper(
            dependingOn: tabIdsWrapper
        )

        webViewPoolCleaningOperation.addDependency(tabIdsWrapper.targetOperation)
        transportsCleaningWrapper.addDependency(wrapper: tabIdsWrapper)

        let resultOperation = ClosureOperation<Void> {
            try webViewPoolCleaningOperation.extractNoCancellableResultData()
            try transportsCleaningWrapper.targetOperation.extractNoCancellableResultData()
        }

        resultOperation.addDependency(webViewPoolCleaningOperation)
        resultOperation.addDependency(transportsCleaningWrapper.targetOperation)

        let dependencies = tabIdsWrapper.allOperations
            + [webViewPoolCleaningOperation]
            + transportsCleaningWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}
