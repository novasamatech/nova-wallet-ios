import Foundation
import Operation_iOS

final class SwipeGovVotingListInteractor {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    private let chain: ChainModel
    private let metaAccount: MetaAccountModel

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?

    init(
        chain: ChainModel,
        metaAccount: MetaAccountModel,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    ) {
        self.chain = chain
        self.metaAccount = metaAccount
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
    }
}

// MARK: SwipeGovVotingListInteractorInputProtocol

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {
    func setup() {
        guard
            let accountId = metaAccount.fetch(for: chain.accountRequest())?.accountId,
            let assetId = chain.utilityAsset()?.assetId
        else {
            return
        }

        subscribeAssetBalance(
            for: accountId,
            chainId: chain.chainId,
            assetId: assetId
        )

        subscribeVotingBasketItems(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension SwipeGovVotingListInteractor: VotingBasketLocalStorageSubscriber, VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], any Error>) {
        switch result {
        case let .success(votingsChanges):
            presenter?.didReceive(votingsChanges.allChangedItems())
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: WalletLocalStorageSubscriber

extension SwipeGovVotingListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, any Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        print(result)
    }
}

// MARK: Private

private extension SwipeGovVotingListInteractor {
    func subscribeAssetBalance(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: assetId
        )
    }

    func subscribeVotingBasketItems(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) {
        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chainId,
            metaId: metaId
        )
    }
}
