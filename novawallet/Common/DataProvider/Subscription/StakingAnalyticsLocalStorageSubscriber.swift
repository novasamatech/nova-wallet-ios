import Foundation
import Operation_iOS

protocol StakingAnalyticsLocalStorageSubscriber where Self: AnyObject {
    var stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol { get }

    var stakingAnalyticsLocalSubscriptionHandler: StakingAnalyticsLocalSubscriptionHandler { get }

    func subscribeWeaklyRewardAnalytics(
        for address: AccountAddress,
        urls: [URL]
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]>?
}

extension StakingAnalyticsLocalStorageSubscriber {
    func subscribeWeaklyRewardAnalytics(
        for address: AccountAddress,
        urls: [URL]
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]>? {
        let provider = stakingAnalyticsLocalSubscriptionFactory
            .getWeaklyAnalyticsProvider(for: address, urls: urls)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[SubqueryRewardItemData]>]) in
            let result = changes.reduceToLastChange()
            self?.stakingAnalyticsLocalSubscriptionHandler.handleWeaklyRewardAnalytics(
                result: .success(result),
                address: address,
                urls: urls
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingAnalyticsLocalSubscriptionHandler.handleWeaklyRewardAnalytics(
                result: .failure(error),
                address: address,
                urls: urls
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

extension StakingAnalyticsLocalStorageSubscriber where Self: StakingAnalyticsLocalSubscriptionHandler {
    var stakingAnalyticsLocalSubscriptionHandler: StakingAnalyticsLocalSubscriptionHandler { self }
}
