import Foundation
import Operation_iOS

final class SwipeGovVotingListInteractor {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol

    private let chainId: ChainModel.Id
    private let metaId: MetaAccountModel.Id

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?

    init(
        chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    ) {
        self.chainId = chainId
        self.metaId = metaId
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
    }
}

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {
    func setup() {
        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chainId,
            metaId: metaId
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
