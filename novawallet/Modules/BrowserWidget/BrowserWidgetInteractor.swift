import UIKit

final class BrowserWidgetInteractor {
    weak var presenter: BrowserWidgetInteractorOutputProtocol?

    private let browserTabManager: DAppBrowserTabsManagerProtocol = DAppBrowserTabsManager.shared
}

extension BrowserWidgetInteractor: BrowserWidgetInteractorInputProtocol {
    func setup() {
        browserTabManager.subscribe(
            self,
            receiveOnSubscription: true
        )
    }

    func closeTabs() {
        browserTabManager.closeAllTabs()
    }
}

extension BrowserWidgetInteractor: DAppBrowserTabsObserver {
    func didReceive(tabs: [UUID: DAppBrowserTabModel]) {
        presenter?.didReceive(tabs)
    }
}
