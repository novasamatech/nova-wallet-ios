import Foundation

protocol TinderGovSetupViewProtocol: BaseReferendumVoteSetupViewProtocol {}

protocol TinderGovSetupPresenterProtocol: BaseReferendumVoteSetupPresenterProtocol {
    func proceed()
}

protocol TinderGovSetupInteractorInputProtocol: AnyObject {
    func process(votingPower: VotingPowerLocal)
}

protocol TinderGovSetupInteractorOutputProtocol: ReferendumVoteSetupInteractorOutputProtocol {
    func didProcessVotingPower()
}

protocol TinderGovSetupWireframeProtocol: BaseReferendumVoteSetupWireframeProtocol, ModalAlertPresenting {
    func showTinderGov(
        from view: ControllerBackedProtocol?,
        locale: Locale
    )
}
