import Foundation
import WebKit

protocol DAppBrowserTabsManagerProtocol {
    func createTab(for dappBrowserModel: DAppBrowserModel) -> DAppBrowserTabModel
    func fetchTab(for id: UUID) -> DAppBrowserTabModel?
    func fetchAllTabs() -> [DAppBrowserTabModel]
}

class DAppBrowserTabsManager {
    private var tabs: [UUID: DAppBrowserTabModel] = [:]

    static let shared = DAppBrowserTabsManager()
}

extension DAppBrowserTabsManager: DAppBrowserTabsManagerProtocol {
    func createTab(for dappBrowserModel: DAppBrowserModel) -> DAppBrowserTabModel {
        let uuid = UUID()
        let tab = DAppBrowserTabModel(
            uuid: uuid,
            url: dappBrowserModel.url,
            isDesktop: dappBrowserModel.isDesktop,
            transports: dappBrowserModel.transports
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
}
