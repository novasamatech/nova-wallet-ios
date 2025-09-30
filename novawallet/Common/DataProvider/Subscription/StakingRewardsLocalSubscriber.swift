import Foundation
import Operation_iOS

protocol StakingRewardsLocalSubscriber: AnyObject {
    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol { get }

    var stakingRewardsLocalSubscriptionHandler: StakingRewardsLocalHandler { get }

    func subscribeTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>?
}

extension StakingRewardsLocalSubscriber {
    func subscribeTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>? {
        guard let totalRewardProvider = try? stakingRewardsLocalSubscriptionFactory.getTotalReward(
            for: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            api: api,
            assetPrecision: assetPrecision
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<TotalRewardItem>]) in
            if let finalValue = changes.reduceToLastChange() {
                self?.stakingRewardsLocalSubscriptionHandler.handleTotalReward(
                    result: .success(finalValue),
                    for: address,
                    api: api
                )
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingRewardsLocalSubscriptionHandler.handleTotalReward(
                result: .failure(error),
                for: address,
                api: api
            )

            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        totalRewardProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return totalRewardProvider
    }
}

extension StakingRewardsLocalSubscriber where Self: StakingRewardsLocalHandler {
    var stakingRewardsLocalSubscriptionHandler: StakingRewardsLocalHandler { self }
}
