import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumVoteSetupInteractor: ReferendumVoteInteractor {
    weak var presenter: ReferendumVoteSetupInteractorOutputProtocol? {
        get {
            basePresenter as? ReferendumVoteSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension ReferendumVoteSetupInteractor: ReferendumVoteSetupInteractorInputProtocol {}
