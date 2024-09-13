import Foundation

final class SwipeGovVotingListPresenter {
    weak var view: SwipeGovVotingListViewProtocol?
    let wireframe: SwipeGovVotingListWireframeProtocol
    let interactor: SwipeGovVotingListInteractorInputProtocol

    init(
        interactor: SwipeGovVotingListInteractorInputProtocol,
        wireframe: SwipeGovVotingListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwipeGovVotingListPresenter: SwipeGovVotingListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func removeItem(with referendumId: ReferendumIdLocal) {
        print(referendumId)
    }

    func selectVoting(for referendumId: ReferendumIdLocal) {
        print(referendumId)
    }
}

extension SwipeGovVotingListPresenter: SwipeGovVotingListInteractorOutputProtocol {
    func didReceive(_ votingBasketItems: [VotingBasketItemLocal]) {
        print(votingBasketItems)
    }

    func didReceive(_ error: Error) {
        print(error)
    }
}
