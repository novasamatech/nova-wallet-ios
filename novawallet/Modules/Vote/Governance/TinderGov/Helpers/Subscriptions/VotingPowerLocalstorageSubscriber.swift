import Foundation
import Operation_iOS

protocol VotingPowerSubscriptionHandler {
    func handleVotingPowerChange(result: Result<[DataProviderChange<VotingPowerLocal>], Error>)
}

protocol VotingPowerLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var votingPowerSubscriptionFactory: VotingPowerLocalSubscriptionFactoryProtocol { get }
    var subscriptionHandler: VotingPowerSubscriptionHandler { get }

    func subscribeToVotingPowerProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingPowerLocal>
}

extension VotingPowerLocalStorageSubscriber {
    func subscribeToVotingPowerProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingPowerLocal> {
        let provider = votingPowerSubscriptionFactory.getVotingPowerProvider(
            for: chainId,
            metaId: metaId
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<VotingPowerLocal>]) in
            let assetBalance = changes.reduceToLastChange()

            self?.subscriptionHandler.handleVotingPowerChange(result: .success(changes))
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleVotingPowerChange(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        // we might receive provider from cache and make sure we are not already observing
        provider.removeObserver(self)

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

extension VotingPowerLocalStorageSubscriber where Self: VotingPowerSubscriptionHandler {
    var subscriptionHandler: VotingPowerSubscriptionHandler { self }
}
