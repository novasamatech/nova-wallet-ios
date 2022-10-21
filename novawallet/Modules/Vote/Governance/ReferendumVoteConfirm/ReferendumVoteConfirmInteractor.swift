import UIKit

final class ReferendumVoteConfirmInteractor {
    weak var presenter: ReferendumVoteConfirmInteractorOutputProtocol!
}

extension ReferendumVoteConfirmInteractor: ReferendumVoteConfirmInteractorInputProtocol {}
