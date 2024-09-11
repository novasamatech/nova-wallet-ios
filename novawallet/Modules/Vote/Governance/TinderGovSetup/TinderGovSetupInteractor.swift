import UIKit

final class TinderGovSetupInteractor: ReferendumVoteInteractor {
    weak var presenter: TinderGovSetupInteractorOutputProtocol? {
        get {
            basePresenter as? TinderGovSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension TinderGovSetupInteractor: TinderGovSetupInteractorInputProtocol {
    func process(votingPower _: VotingPowerLocal) {}
}
