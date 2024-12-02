import UIKit
import Operation_iOS

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?

    private let tabManager: DAppBrowserTabManagerProtocol

    init(tabManager: DAppBrowserTabManagerProtocol) {
        self.tabManager = tabManager
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
