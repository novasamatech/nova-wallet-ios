import Foundation
import Operation_iOS

protocol DAppBrowserTabsObserver: AnyObject {
    func didReceiveUpdatedTabs(_ tabs: [DAppBrowserTab])
}

protocol DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?>
    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]>

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab>

    func updateRenderForTab(
        with id: UUID,
        renderer: DAppBrowserTabRendererProtocol
    ) -> CompoundOperationWrapper<Void>

    func removeTab(with id: UUID)

    func removeAll()

    func addObserver(_ observer: DAppBrowserTabsObserver)
}
