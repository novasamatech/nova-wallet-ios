import UIKit

final class ReferendumDetailsInteractor {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol!
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {}
