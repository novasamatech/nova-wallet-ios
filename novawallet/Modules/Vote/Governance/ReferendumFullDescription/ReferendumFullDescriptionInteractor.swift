import UIKit

final class ReferendumFullDescriptionInteractor {
    weak var presenter: ReferendumFullDescriptionInteractorOutputProtocol!
}

extension ReferendumFullDescriptionInteractor: ReferendumFullDescriptionInteractorInputProtocol {}
