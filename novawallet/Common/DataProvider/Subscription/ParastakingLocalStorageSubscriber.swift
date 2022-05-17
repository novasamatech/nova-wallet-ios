import Foundation
import RobinHood

protocol ParastakingLocalStorageSubscriber: AnyObject {
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }

    var parastakingLocalSubscriptionHandler: ParastakingLocalStorageHandler { get }

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
            self?.parastakingLocalSubscriptionHandler.handleParastakingRound(
                result: .success(round),
                for: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parastakingLocalSubscriptionHandler.handleParastakingRound(
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
            self?.parastakingLocalSubscriptionHandler.handleParastakingDelegatorState(
                result: .success(delegator),
                for: chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parastakingLocalSubscriptionHandler.handleParastakingDelegatorState(
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
            self?.parastakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
                result: .success(requests),
                for: chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parastakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
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
}

extension ParastakingLocalStorageSubscriber where Self: ParastakingLocalStorageHandler {
    var parastakingLocalSubscriptionHandler: ParastakingLocalStorageHandler { self }
}
