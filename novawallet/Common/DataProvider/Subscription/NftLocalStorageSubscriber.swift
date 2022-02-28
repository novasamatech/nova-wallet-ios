import Foundation
import RobinHood

protocol NftLocalStorageSubscriber: AnyObject {
    var nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol { get }

    var nftLocalSubscriptionHandler: NftLocalSubscriptionHandler { get }

    func subscribeToNftProvider(
        for wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> StreamableProvider<NftModel>?
}

extension NftLocalStorageSubscriber {
    func subscribeToNftProvider(
        for wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> StreamableProvider<NftModel>? {
        let provider = nftLocalSubscriptionFactory.getNftProvider(for: wallet, chains: chains)

        let updateClosure = { [weak self] (changes: [DataProviderChange<NftModel>]) in
            self?.nftLocalSubscriptionHandler.handleNfts(result: .success(changes), wallet: wallet)
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.nftLocalSubscriptionHandler.handleNfts(result: .failure(error), wallet: wallet)
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
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

extension NftLocalStorageSubscriber where Self: NftLocalSubscriptionHandler {
    var nftLocalSubscriptionHandler: NftLocalSubscriptionHandler { self }
}
