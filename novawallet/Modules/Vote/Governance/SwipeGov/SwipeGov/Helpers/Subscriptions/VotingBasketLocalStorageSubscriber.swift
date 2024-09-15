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
            self?.subscriptionHandler.handleVotingBasketItems(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleVotingBasketItems(result: .failure(error))
            return
        }

        provider.removeObserver(self)

        addStreamableProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        return provider
    }
}

extension VotingBasketLocalStorageSubscriber where Self: VotingBasketSubscriptionHandler {
    var subscriptionHandler: VotingBasketSubscriptionHandler { self }
}
