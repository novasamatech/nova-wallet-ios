import Foundation
import Operation_iOS

protocol VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], Error>)
}

protocol VotingBasketLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol { get }
    var subscriptionHandler: VotingBasketSubscriptionHandler { get }

    func subscribeToVotingBasketItemProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal>
}

extension VotingBasketLocalStorageSubscriber {
    func subscribeToVotingBasketItemProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal> {
        let provider = votingBasketSubscriptionFactory.getVotingBasketItemsProvider(
            for: chainId,
            metaId: metaId
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<VotingBasketItemLocal>]) in
            let assetBalance = changes.reduceToLastChange()

            self?.subscriptionHandler.handleVotingBasketItems(result: .success(changes))
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleVotingBasketItems(result: .failure(error))
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

extension VotingBasketLocalStorageSubscriber where Self: VotingBasketSubscriptionHandler {
    var subscriptionHandler: VotingBasketSubscriptionHandler { self }
}
