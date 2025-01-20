import Foundation
import Operation_iOS

protocol DAppBrowserTabsObserver: AnyObject {
    func didReceiveUpdatedTabs(_ tabs: [DAppBrowserTab])
}

protocol DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?>

    func getAllTabs(for metaIds: Set<MetaAccountModel.Id>?) -> CompoundOperationWrapper<[DAppBrowserTab]>

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab>

    func updateRenderForTab(
        with id: UUID,
        render: DAppBrowserTabRenderProtocol
    ) -> CompoundOperationWrapper<Void>

    func cleanTransport(for tabIds: Set<UUID>) -> BaseOperation<Void>

    func removeTab(with id: UUID)

    func removeAll(for metaIds: Set<MetaAccountModel.Id>?)

    func removeAllWrapper(for metaIds: Set<MetaAccountModel.Id>?) -> CompoundOperationWrapper<Set<UUID>>

    func addObserver(
        _ observer: DAppBrowserTabsObserver,
        sendOnSubscription: Bool
    )
}

extension DAppBrowserTabManagerProtocol {
    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]> {
        getAllTabs(for: nil)
    }

    func removeAll() {
        removeAll(for: nil)
    }

    func removeAllWrapper() -> CompoundOperationWrapper<Set<UUID>> {
        removeAllWrapper(for: nil)
    }
}
