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
        using dependencies: WalletStorageCleaningDependencies
    ) -> CompoundOperationWrapper<Set<UUID>> {
        let tabsWrapper = createTabsWrapper(using: dependencies)

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
        using dependencies: WalletStorageCleaningDependencies
    ) -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let metaIdsOperation = createMetaIdsOperation(using: dependencies)

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
        using dependencies: WalletStorageCleaningDependencies
    ) -> ClosureOperation<Set<MetaAccountModel.Id>> {
        ClosureOperation {
            let allWallets = try dependencies.allWalletsClosure?() ?? [:]
            let updatedWallets = try dependencies.changedItemsClosure()

            let cleanTabsWalletIds = updatedWallets
                .filter {
                    let currentWallet = allWallets[$0.metaId]
                    let updatedWallet = $0

                    return currentWallet?.chainAccounts != updatedWallet.chainAccounts
                }.map(\.metaId)

            return Set(cleanTabsWalletIds)
        }
    }
}

// MARK: WalletStorageCleaning

extension UpdatedWalletBrowserStateCleaner: WalletStorageCleaning {
    func cleanStorage(
        using dependencies: WalletStorageCleaningDependencies
    ) -> CompoundOperationWrapper<Void> {
        let tabIdsWrapper = createTabIdsWrapper(using: dependencies)

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
