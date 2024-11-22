import UIKit

final class DAppBrowserTabsInteractor {
    weak var presenter: DAppBrowserTabsInteractorOutputProtocol?

    private let tabManager: DAppBrowserTabsManagerProtocol

    init(tabManager: DAppBrowserTabsManagerProtocol) {
        self.tabManager = tabManager
    }
}

extension DAppBrowserTabsInteractor: DAppBrowserTabsInteractorInputProtocol {
    func setup() {
        let models = tabManager.fetchAllTabs()

        presenter?.didReceiveTabs(models)
    }
}
