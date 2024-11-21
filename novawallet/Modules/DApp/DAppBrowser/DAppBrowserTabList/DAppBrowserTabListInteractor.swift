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

        let fetchAllWrapper = tabManager.getAllTabs()

        execute(
            wrapper: fetchAllWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tabs):
                self?.presenter?.didReceiveTabs(tabs)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
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
