import UIKit

final class ReferendumVoteSetupInteractor {
    weak var presenter: ReferendumVoteSetupInteractorOutputProtocol?
}

extension ReferendumVoteSetupInteractor: ReferendumVoteSetupInteractorInputProtocol {}
