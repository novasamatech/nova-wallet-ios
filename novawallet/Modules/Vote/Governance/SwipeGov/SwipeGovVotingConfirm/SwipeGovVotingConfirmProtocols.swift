import Foundation
import BigInt

protocol SwipeGovVotingConfirmViewProtocol: BaseReferendumVoteConfirmViewProtocol {
    func didReceive(referendaCount: Int)
}

protocol SwipeGovVotingConfirmPresenterProtocol: BaseReferendumVoteConfirmPresenterProtocol {}

protocol SwipeGovVotingConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(votes: [ReferendumNewVote])
    func submit(
        votes: [ReferendumNewVote],
        limitingBy amount: BigUInt
    )
}

protocol SwipeGovVotingConfirmInteractorOutputProtocol: BaseReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveSuccessBatchVoting()
}

protocol SwipeGovVotingConfirmWireframeProtocol: BaseReferendumVoteConfirmWireframeProtocol {}