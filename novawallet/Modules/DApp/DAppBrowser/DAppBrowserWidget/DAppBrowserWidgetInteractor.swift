import UIKit
import Operation_iOS

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?

    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings

    private let tabManager: DAppBrowserTabManagerProtocol

    private let removedWalletsCleaner: WalletStorageCleaning
    private let updatedWalletsCleaner: WalletStorageCleaning

    private let operationQueue: OperationQueue

    private let logger: LoggerProtocol

    private var selectedWalletProvider: StreamableProvider<ManagedMetaAccountModel>?
    private var allWallets: [MetaAccountModel.Id: ManagedMetaAccountModel] = [:]

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        removedWalletsCleaner: WalletStorageCleaning,
        updatedWalletsCleaner: WalletStorageCleaning,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.tabManager = tabManager
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.selectedWalletSettings = selectedWalletSettings
        self.removedWalletsCleaner = removedWalletsCleaner
        self.updatedWalletsCleaner = updatedWalletsCleaner
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: Private

// TODO: Move this logic to WalletUpdateMediator
private extension DAppBrowserWidgetInteractor {
    func removedWalletsCleaningWrapper(
        removedWallets: [MetaAccountModel]
    ) -> CompoundOperationWrapper<Void> {
        let removedWalletsCleaningDependencies = WalletStorageCleaningDependencies(
            changedItemsClosure: { removedWallets },
            allWalletsClosure: nil
        )

        return removedWalletsCleaner.cleanStorage(
            using: removedWalletsCleaningDependencies
        )
    }

    func updatedWalletsCleaningWrapper(
        updatedWallets: [MetaAccountModel],
        allWallets: [MetaAccountModel.Id: MetaAccountModel]
    ) -> CompoundOperationWrapper<Void> {
        let removedWalletsCleaningDependencies = WalletStorageCleaningDependencies(
            changedItemsClosure: { updatedWallets },
            allWalletsClosure: { allWallets }
        )

        return updatedWalletsCleaner.cleanStorage(
            using: removedWalletsCleaningDependencies
        )
    }

    func createCleaningWrapper(
        removedWallets: [MetaAccountModel],
        updatedWallets: [MetaAccountModel],
        allWallets: [MetaAccountModel.Id: MetaAccountModel]
    ) -> CompoundOperationWrapper<Void> {
        let removedWalletCleaningWrapper = removedWalletsCleaningWrapper(
            removedWallets: removedWallets
        )
        let updatedWalletsCleaningWrapper = updatedWalletsCleaningWrapper(
            updatedWallets: updatedWallets,
            allWallets: allWallets
        )

        let resultOperation = ClosureOperation<Void> {
            try removedWalletCleaningWrapper.targetOperation.extractNoCancellableResultData()
            try updatedWalletsCleaningWrapper.targetOperation.extractNoCancellableResultData()
        }

        resultOperation.addDependency(removedWalletCleaningWrapper.targetOperation)
        resultOperation.addDependency(updatedWalletsCleaningWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: removedWalletCleaningWrapper.allOperations + updatedWalletsCleaningWrapper.allOperations
        )
    }

    func processWalletList(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let removedWallets: [MetaAccountModel] = changes
            .compactMap { change in
                guard change.isDeletion else { return nil }

                return allWallets[change.identifier]?.info
            }

        let updatedWallets: [MetaAccountModel] = changes
            .compactMap { change in
                guard case let .update(wallet) = change else { return nil }

                return wallet.info
            }

        let allItems = changes.mergeToDict(allWallets)

        let currentAllWallets = if allWallets.isEmpty {
            allItems
        } else {
            allWallets
        }

        allWallets = allItems

        let cleaningWrapper = createCleaningWrapper(
            removedWallets: removedWallets,
            updatedWallets: updatedWallets,
            allWallets: currentAllWallets.mapValues(\.info)
        )

        operationQueue.addOperations(
            cleaningWrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

// MARK: DAppBrowserWidgetInteractorInputProtocol

extension DAppBrowserWidgetInteractor: DAppBrowserWidgetInteractorInputProtocol {
    func setup() {
        selectedWalletProvider = subscribeAllWalletsProvider()
        tabManager.addObserver(
            self,
            sendOnSubscription: false
        )
    }

    func closeTabs() {
        tabManager.removeAll()
    }
}

// MARK: DAppBrowserTabsObserver

extension DAppBrowserWidgetInteractor: DAppBrowserTabsObserver {
    func didReceiveUpdatedTabs(_ tabs: [DAppBrowserTab]) {
        let tabsById = tabs.reduce(into: [UUID: DAppBrowserTab]()) { $0[$1.uuid] = $1 }

        presenter?.didReceive(tabsById)
    }
}

// MARK: WalletListLocalStorageSubscriber

extension DAppBrowserWidgetInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(
        result: Result<[DataProviderChange<ManagedMetaAccountModel>], any Error>
    ) {
        switch result {
        case let .success(changes):
            processWalletList(changes)
        case let .failure(error):
            logger.error("Failed on WalletList local subscription with error: \(error.localizedDescription)")
        }
    }
}
