import Foundation
import RobinHood

protocol ParastakingLocalStorageSubscriber: AnyObject {
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }

    var stakingLocalSubscriptionHandler: ParastakingLocalStorageHandler { get }

    func subscribeToRound(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<ParachainStaking.DecodedRoundInfo>?

    func subscribeToDelegatorState(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedDelegator>?

    func subscribeToScheduledRequests(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedScheduledRequests>?

    func subscribeTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>?
}

extension ParastakingLocalStorageSubscriber {
    func subscribeToRound(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<ParachainStaking.DecodedRoundInfo>? {
        guard let roundProvider = try? stakingLocalSubscriptionFactory.getRoundProvider(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedRoundInfo>]) -> Void

        updateClosure = { [weak self] changes in
            let round = changes.reduceToLastChange()?.item
            self?.stakingLocalSubscriptionHandler.handleParastakingRound(
                result: .success(round),
                for: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleParastakingRound(
                result: .failure(error),
                for: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        roundProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return roundProvider
    }

    func subscribeToDelegatorState(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedDelegator>? {
        guard
            let delegatorProvider =
            try? stakingLocalSubscriptionFactory.getDelegatorStateProvider(
                for: chainId,
                accountId: accountId
            ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedDelegator>]) -> Void

        updateClosure = { [weak self] changes in
            let delegator = changes.reduceToLastChange()?.item
            self?.stakingLocalSubscriptionHandler.handleParastakingDelegatorState(
                result: .success(delegator),
                for: chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleParastakingDelegatorState(
                result: .failure(error),
                for: chainId,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        delegatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return delegatorProvider
    }

    func subscribeToScheduledRequests(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedScheduledRequests>? {
        guard
            let requestsProvider =
            try? stakingLocalSubscriptionFactory.getScheduledRequestsProvider(
                for: chainId,
                accountId: accountId
            )
        else {
            return nil
        }

        let updateBlock: ([DataProviderChange<ParachainStaking.DecodedScheduledRequests>]) -> Void

        updateBlock = { [weak self] changes in
            let requests = changes.reduceToLastChange()?.item
            self?.stakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
                result: .success(requests),
                for: chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
                result: .failure(error),
                for: chainId,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        requestsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateBlock,
            failing: failureClosure,
            options: options
        )

        return requestsProvider
    }

    func subscribeTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>? {
        guard let totalRewardProvider = try? stakingLocalSubscriptionFactory.getTotalReward(
            for: address,
            api: api,
            assetPrecision: assetPrecision
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<TotalRewardItem>]) in
            if let finalValue = changes.reduceToLastChange() {
                self?.stakingLocalSubscriptionHandler.handleTotalReward(
                    result: .success(finalValue),
                    for: address,
                    api: api
                )
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleTotalReward(
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

extension ParastakingLocalStorageSubscriber where Self: ParastakingLocalStorageHandler {
    var stakingLocalSubscriptionHandler: ParastakingLocalStorageHandler { self }
}
