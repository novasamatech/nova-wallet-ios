import Foundation
import WebKit
import SoraKeystore

protocol DAppBrowserTabsManagerProtocol {
    func createTab(for dappBrowserModel: DAppBrowserModel) -> DAppBrowserTabModel
    func fetchTab(for id: UUID) -> DAppBrowserTabModel?
    func fetchAllTabs() -> [DAppBrowserTabModel]
    func updateStateForTab(with url: URL, _ state: Any?)
}

class DAppBrowserTabsManager {
    private var tabs: [UUID: DAppBrowserTabModel] = [:]

    private let settingsManager: SettingsManagerProtocol = SettingsManager.shared

    static let shared = DAppBrowserTabsManager()
}

extension DAppBrowserTabsManager: DAppBrowserTabsManagerProtocol {
    func createTab(for dappBrowserModel: DAppBrowserModel) -> DAppBrowserTabModel {
        let state = settingsManager.webViewStates?[dappBrowserModel.url.absoluteString]

        let uuid = UUID()

        let tab = DAppBrowserTabModel(
            uuid: uuid,
            url: dappBrowserModel.url,
            isDesktop: dappBrowserModel.isDesktop,
            transports: dappBrowserModel.transports,
            state: state
        )

        tabs[uuid] = tab

        return tab
    }

    func fetchTab(for id: UUID) -> DAppBrowserTabModel? {
        tabs[id]
    }

    func fetchAllTabs() -> [DAppBrowserTabModel] {
        Array(tabs.values)
    }

    func updateStateForTab(with url: URL, _ state: Any?) {
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
                isDesktop: tab.isDesktop,
                transports: tab.transports,
                state: data
            )

            tabs[tab.uuid] = updatedTab
        }
    }
}
