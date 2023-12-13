import Foundation
import RobinHood

protocol ProxyListLocalStorageSubscriber where Self: AnyObject {
    var proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol { get }

    var proxyListLocalSubscriptionHandler: ProxyListLocalSubscriptionHandler { get }

    func subscribeAllProxies() -> StreamableProvider<ProxyAccountModel>?
}

extension ProxyListLocalStorageSubscriber {
    func subscribeAllProxies() -> StreamableProvider<ProxyAccountModel>? {
        guard let provider = try? proxyListLocalSubscriptionFactory.getProxyListProvider(
            statuses: [.new, .revoked, .active]
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ProxyAccountModel>]) in
            self?.proxyListLocalSubscriptionHandler.handleAllProxies(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.proxyListLocalSubscriptionHandler.handleAllProxies(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
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

extension ProxyListLocalStorageSubscriber where Self: ProxyListLocalSubscriptionHandler {
    var proxyListLocalSubscriptionHandler: ProxyListLocalSubscriptionHandler { self }
}
