import UIKit
import Operation_iOS

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?

    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let selectedWalletSettings: SelectedWalletSettings

    private let tabManager: DAppBrowserTabManagerProtocol

    private let walletCleaner: WalletStorageCleaning

    private let operationQueue: OperationQueue

    private let logger: LoggerProtocol

    private var selectedWalletProvider: StreamableProvider<ManagedMetaAccountModel>?
    private var allWallets: [MetaAccountModel.Id: ManagedMetaAccountModel]?

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        walletCleaner: WalletStorageCleaning,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.tabManager = tabManager
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.selectedWalletSettings = selectedWalletSettings
        self.walletCleaner = walletCleaner
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: Private

// TODO: Move this logic to WalletUpdateMediator
private extension DAppBrowserWidgetInteractor {
    func processWalletList(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let walletsBeforeChanges = allWallets

        allWallets = changes.mergeToDict(walletsBeforeChanges ?? [:])
        
        guard let walletsBeforeChanges else { return }

        let walletCleaningProviders = WalletStorageCleaningProviders(
            changesProvider: { changes },
            walletsBeforeChangesProvider: { walletsBeforeChanges }
        )
        let cleaningWrapper = walletCleaner.cleanStorage(using: walletCleaningProviders)

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
