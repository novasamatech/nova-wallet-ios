import Foundation
import Operation_iOS

protocol ProxyListLocalStorageSubscriber where Self: AnyObject {
    var proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol { get }

    var proxyListLocalSubscriptionHandler: ProxyListLocalSubscriptionHandler { get }

    func subscribeAllProxies() -> StreamableProvider<DelegatedAccount.ProxyAccountModel>?

    func subscribeProxies(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        modifyInternalList: @escaping (ProxyDefinition) -> ProxyDefinition
    ) -> AnyDataProvider<DecodedProxyDefinition>?
}

extension ProxyListLocalStorageSubscriber {
    func subscribeAllProxies() -> StreamableProvider<DelegatedAccount.ProxyAccountModel>? {
        guard let provider = try? proxyListLocalSubscriptionFactory.getProxyListProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DelegatedAccount.ProxyAccountModel>]) in
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

    func subscribeProxies(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        modifyInternalList: @escaping (ProxyDefinition) -> ProxyDefinition
    ) -> AnyDataProvider<DecodedProxyDefinition>? {
        guard let provider = try? proxyListLocalSubscriptionFactory.getProxyListProvider(
            for: accountId,
            chainId: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedProxyDefinition>]) in
            let proxies = changes.reduceToLastChange()?.item.map { modifyInternalList($0) } ?? nil

            self?.proxyListLocalSubscriptionHandler.handleProxies(
                result: .success(proxies),
                accountId: accountId,
                chainId: chainId
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.proxyListLocalSubscriptionHandler.handleProxies(
                result: .failure(error),
                accountId: accountId,
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
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
