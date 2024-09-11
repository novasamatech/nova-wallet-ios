import Foundation

protocol TinderGovSetupViewProtocol: BaseReferendumVoteSetupViewProtocol {}

protocol TinderGovSetupPresenterProtocol: BaseReferendumVoteSetupPresenterProtocol {
    func proceed()
}

protocol TinderGovSetupInteractorInputProtocol: ReferendumVoteSetupInteractorInputProtocol {
    func process(votingPower: VotingPowerLocal)
}

protocol TinderGovSetupInteractorOutputProtocol: ReferendumVoteSetupInteractorOutputProtocol {
    func didProcessVotingPower()
}

protocol TinderGovSetupWireframeProtocol: BaseReferendumVoteSetupWireframeProtocol {
    func showTinderGov(from view: ControllerBackedProtocol?)
}
