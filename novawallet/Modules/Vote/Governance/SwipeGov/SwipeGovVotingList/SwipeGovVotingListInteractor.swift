import Foundation
import Operation_iOS

final class SwipeGovVotingListInteractor {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol

    private let chainId: ChainModel.Id
    private let metaAccount: MetaAccountModel

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?

    init(
        chainId: ChainModel.Id,
        metaAccount: MetaAccountModel,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    ) {
        self.chainId = chainId
        self.metaAccount = metaAccount
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
    }
}

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {
    func setup() {
        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chainId,
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
