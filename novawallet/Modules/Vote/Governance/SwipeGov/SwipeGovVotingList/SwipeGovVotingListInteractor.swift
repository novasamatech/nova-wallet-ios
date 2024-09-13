import UIKit

final class SwipeGovVotingListInteractor {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?
}

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {}
