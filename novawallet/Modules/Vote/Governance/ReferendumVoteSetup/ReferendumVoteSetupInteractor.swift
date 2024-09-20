import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumVoteSetupInteractor: ReferendumObservingVoteInteractor {
    weak var presenter: ReferendumObservingVoteInteractorOutputProtocol? {
        get { basePresenter as? ReferendumObservingVoteInteractorOutputProtocol }
        set { basePresenter = newValue }
    }
}

extension ReferendumVoteSetupInteractor: ReferendumVoteSetupInteractorInputProtocol {}
