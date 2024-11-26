import UIKit

final class DAppBrowserTabListInteractor {
    weak var presenter: DAppBrowserTabListInteractorOutputProtocol?

    private let tabManager: DAppBrowserTabManagerProtocol
    private let operationQueue: OperationQueue

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.tabManager = tabManager
        self.operationQueue = operationQueue
    }
}

// MARK: DAppBrowserTabListInteractorInputProtocol

extension DAppBrowserTabListInteractor: DAppBrowserTabListInteractorInputProtocol {
    func setup() {
        tabManager.addObserver(self)
    }

    func closeTab(with id: UUID) {
        tabManager.removeTab(with: id)
    }

    func closeAllTabs() {
        tabManager.removeAll()
    }
}

// MARK: DAppBrowserTabsObserver

extension DAppBrowserTabListInteractor: DAppBrowserTabsObserver {
    func didReceiveUpdatedTabs(_ tabs: [DAppBrowserTab]) {
        presenter?.didReceiveTabs(tabs)
    }
}
