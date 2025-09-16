import UIKit
import Operation_iOS

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings

    private let tabManager: DAppBrowserTabManagerProtocol

    private let operationQueue: OperationQueue

    private let logger: LoggerProtocol

    private var allWallets: [MetaAccountModel.Id: ManagedMetaAccountModel]?

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.tabManager = tabManager
        self.selectedWalletSettings = selectedWalletSettings
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: DAppBrowserWidgetInteractorInputProtocol

extension DAppBrowserWidgetInteractor: DAppBrowserWidgetInteractorInputProtocol {
    func setup() {
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
