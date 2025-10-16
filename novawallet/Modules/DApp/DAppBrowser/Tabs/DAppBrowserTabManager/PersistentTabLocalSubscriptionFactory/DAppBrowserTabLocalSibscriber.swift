import Foundation
import Operation_iOS

protocol DAppBrowserTabLocalSubscriber: AnyObject {
    var tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol { get }

    var tabsLocalSubscriptionHandler: DAppBrowserTabLocalSubscriptionHandler { get }

    func subscribeToBrowserTabs(
        _ metaId: MetaAccountModel.Id?
    ) -> StreamableProvider<DAppBrowserTab.PersistenceModel>
}

extension DAppBrowserTabLocalSubscriber {
    func subscribeToBrowserTabs(
        _ metaId: MetaAccountModel.Id?
    ) -> StreamableProvider<DAppBrowserTab.PersistenceModel> {
        let provider = tabsSubscriptionFactory.getTabsProvider(metaId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<DAppBrowserTab.PersistenceModel>]) in
            self?.tabsLocalSubscriptionHandler.handleBrowserTabs(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.tabsLocalSubscriptionHandler.handleBrowserTabs(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension DAppBrowserTabLocalSubscriber where Self: DAppBrowserTabLocalSubscriptionHandler {
    var tabsLocalSubscriptionHandler: DAppBrowserTabLocalSubscriptionHandler { self }
}
