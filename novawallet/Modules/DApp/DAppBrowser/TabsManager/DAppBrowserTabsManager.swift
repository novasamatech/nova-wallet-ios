import Foundation
import WebKit
import SoraKeystore

protocol DAppBrowserTabsObserver: AnyObject {
    func didReceive(tabs: [UUID: DAppBrowserTabModel])
}

protocol DAppBrowserTabsManagerProtocol {
    func createTab(
        for dappBrowserModel: DAppBrowserModel,
        browserPage: DAppBrowserPage?
    ) -> DAppBrowserTabModel
    func closeAllTabs()
    func fetchTab(for id: UUID) -> DAppBrowserTabModel?
    func fetchAllTabs() -> [DAppBrowserTabModel]
    func updateStateForTab(
        with url: URL,
        _ state: Any?
    )
    func subscribe(
        _ observer: DAppBrowserTabsObserver,
        receiveOnSubscription: Bool
    )
}

class DAppBrowserTabsManager {
    private var tabs: [UUID: DAppBrowserTabModel] = [:]
    private var observers: [WeakWrapper] = []

    private let settingsManager: SettingsManagerProtocol = SettingsManager.shared

    static let shared = DAppBrowserTabsManager()
}

extension DAppBrowserTabsManager: DAppBrowserTabsManagerProtocol {
    func closeAllTabs() {
        clearEmptyWrappers()

        settingsManager.webViewStates = [:]
        tabs = [:]

        notifyObservers()
    }

    func createTab(
        for dappBrowserModel: DAppBrowserModel,
        browserPage: DAppBrowserPage?
    ) -> DAppBrowserTabModel {
        clearEmptyWrappers()

        let state = settingsManager.webViewStates?[dappBrowserModel.url.absoluteString]

        let uuid = UUID()

        let tab = DAppBrowserTabModel(
            uuid: uuid,
            url: dappBrowserModel.url,
            title: browserPage?.title,
            isDesktop: dappBrowserModel.isDesktop,
            transports: dappBrowserModel.transports,
            state: state
        )

        tabs[uuid] = tab

        notifyObservers()

        return tab
    }

    func fetchTab(for id: UUID) -> DAppBrowserTabModel? {
        clearEmptyWrappers()

        return tabs[id]
    }

    func fetchAllTabs() -> [DAppBrowserTabModel] {
        clearEmptyWrappers()

        return Array(tabs.values)
    }

    func updateStateForTab(
        with url: URL,
        _ state: Any?
    ) {
        clearEmptyWrappers()

        guard let nsData = state as? NSData else {
            return
        }

        let key = url.absoluteString

        var dict: [String: Data] = settingsManager.webViewStates ?? [:]

        let data = Data(referencing: nsData)
        dict[key] = data

        settingsManager.webViewStates = dict

        if let tab = tabs.values.first(where: { $0.url == url }) {
            let updatedTab = DAppBrowserTabModel(
                uuid: tab.uuid,
                url: tab.url,
                title: tab.title,
                isDesktop: tab.isDesktop,
                transports: tab.transports,
                state: data
            )

            tabs[tab.uuid] = updatedTab
        }
    }

    func subscribe(
        _ observer: DAppBrowserTabsObserver,
        receiveOnSubscription: Bool
    ) {
        clearEmptyWrappers()

        guard !observers.contains(where: { $0.target === observer }) else {
            return
        }

        if receiveOnSubscription {
            observer.didReceive(tabs: tabs)
        }

        observers.append(WeakWrapper(target: observer))
    }

    private func notifyObservers() {
        observers.forEach {
            ($0.target as? DAppBrowserTabsObserver)?.didReceive(tabs: tabs)
        }
    }

    private func clearEmptyWrappers() {
        observers = observers.filter { $0.target != nil }
    }
}
