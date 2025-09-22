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

            guard !tabIds.isEmpty else {
                return .createWithResult(())
            }

            let cleaningOperation = browserTabManager.cleanTransport(for: tabIds)

            return CompoundOperationWrapper(targetOperation: cleaningOperation)
        }
    }

    func createWebViewCleaningOperation(
        dependingOn tabIdsWrapper: CompoundOperationWrapper<Set<UUID>>
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { [weak self] completion in
            let tabIds = try tabIdsWrapper.targetOperation.extractNoCancellableResultData()

            guard !tabIds.isEmpty else {
                completion(.success(()))
                return
            }

            DispatchQueue.main.async {
                tabIds.forEach { tabId in
                    self?.webViewPoolEraser.removeWebView(for: tabId)
                }
                completion(.success(()))
            }
        }
    }

    func createTabIdsWrapper(
        for metaIds: Set<MetaAccountModel.Id>
    ) -> CompoundOperationWrapper<Set<UUID>> {
        let tabsWrapper = browserTabManager.getAllTabs(for: metaIds)

        let mappingOperation = ClosureOperation<Set<UUID>> {
            let tabIds = try tabsWrapper.targetOperation
                .extractNoCancellableResultData()
                .map(\.uuid)

            return Set(tabIds)
        }

        mappingOperation.addDependency(tabsWrapper.targetOperation)

        return tabsWrapper.insertingTail(operation: mappingOperation)
    }

    func extractMetaIds(
        from providers: WalletStorageCleaningProviders
    ) -> Set<MetaAccountModel.Id> {
        let walletsBeforeChanges = providers.walletsBeforeChangesProvider()
        let updatedWallets = providers.changesProvider()
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

// MARK: WalletStorageCleaning

extension UpdatedWalletBrowserStateCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let metaIds = extractMetaIds(from: providers)

        guard !metaIds.isEmpty else {
            return .createWithResult(())
        }

        let tabIdsWrapper = createTabIdsWrapper(for: metaIds)

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
