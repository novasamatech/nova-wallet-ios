import Foundation
import Operation_iOS

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

    func subscribeToCandidateMetadata(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedCandidateMetadata>?

    func subscribeToScheduledRequests(
        for chainId: ChainModel.Id,
        delegatorId: AccountId
    ) -> StreamableProvider<ParachainStaking.MappedScheduledRequest>?
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

    func subscribeToCandidateMetadata(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<ParachainStaking.DecodedCandidateMetadata>? {
        guard
            let metadataProvider =
            try? stakingLocalSubscriptionFactory.getCandidateMetadataProvider(
                for: chainId,
                accountId: accountId
            ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ParachainStaking.DecodedCandidateMetadata>]) -> Void

        updateClosure = { [weak self] changes in
            let metadata = changes.reduceToLastChange()?.item
            self?.stakingLocalSubscriptionHandler.handleParastakingCandidateMetadata(
                result: .success(metadata),
                for: chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleParastakingCandidateMetadata(
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

        metadataProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return metadataProvider
    }

    func subscribeToScheduledRequests(
        for chainId: ChainModel.Id,
        delegatorId: AccountId
    ) -> StreamableProvider<ParachainStaking.MappedScheduledRequest>? {
        guard
            let requestsProvider =
            try? stakingLocalSubscriptionFactory.getScheduledRequestsProvider(
                for: chainId,
                delegatorId: delegatorId
            )
        else {
            return nil
        }

        let updateBlock: ([DataProviderChange<ParachainStaking.MappedScheduledRequest>]) -> Void

        updateBlock = { [weak self] changes in
            let requests = changes.reduceToLastChange()?.item
            self?.stakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
                result: .success(requests),
                for: chainId,
                delegatorId: delegatorId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleParastakingScheduledRequests(
                result: .failure(error),
                for: chainId,
                delegatorId: delegatorId
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
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
    var stakingLocalSubscriptionHandler: ParastakingLocalStorageHandler { self }
}
