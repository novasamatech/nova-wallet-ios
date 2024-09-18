import Foundation

protocol SwipeGovVotingConfirmViewProtocol: BaseReferendumVoteConfirmViewProtocol {
    func didReceive(referendaCount: Int)
}

protocol SwipeGovVotingConfirmPresenterProtocol: BaseReferendumVoteConfirmPresenterProtocol {}


protocol SwipeGovVotingConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(votingItems: [VotingBasketItemLocal])
}

protocol SwipeGovVotingConfirmInteractorOutputProtocol: BaseReferendumVoteConfirmInteractorOutputProtocol {}

protocol SwipeGovVotingConfirmWireframeProtocol: BaseReferendumVoteConfirmWireframeProtocol {}
