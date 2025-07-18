import Foundation
import BigInt

protocol SwipeGovVotingConfirmViewProtocol: BaseReferendumVoteConfirmViewProtocol {
    func didReceive(referendaCount: Int)
}

protocol SwipeGovVotingConfirmPresenterProtocol: BaseReferendumVoteConfirmPresenterProtocol {}

protocol SwipeGovVotingConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(votes: [ReferendumNewVote])
}

protocol SwipeGovVotingConfirmInteractorOutputProtocol: BaseReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveSuccessBatchVoting(_ sender: ExtrinsicSenderResolution?)
}

protocol SwipeGovVotingConfirmWireframeProtocol: BaseReferendumVoteConfirmWireframeProtocol {}
