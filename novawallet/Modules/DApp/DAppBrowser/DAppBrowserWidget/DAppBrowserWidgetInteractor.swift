import UIKit
import Operation_iOS

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?

    private let tabManager: DAppBrowserTabManagerProtocol
    private let eventCenter: EventCenterProtocol

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.tabManager = tabManager
        self.eventCenter = eventCenter
    }
}

// MARK: DAppBrowserWidgetInteractorInputProtocol

extension DAppBrowserWidgetInteractor: DAppBrowserWidgetInteractorInputProtocol {
    func setup() {
        tabManager.addObserver(
            self,
            sendOnSubscription: false
        )
        eventCenter.add(
            observer: self,
            dispatchIn: .main
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

// MARK: EventVisitorProtocol

extension DAppBrowserWidgetInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        presenter?.didReceiveWalletChanged()
    }
}
