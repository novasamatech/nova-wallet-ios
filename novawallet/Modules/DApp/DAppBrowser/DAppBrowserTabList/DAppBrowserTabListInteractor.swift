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

extension DAppBrowserTabListInteractor: DAppBrowserTabListInteractorInputProtocol {
    func setup() {
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
                print(error)
            }
        }
    }
}
