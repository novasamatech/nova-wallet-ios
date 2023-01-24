import UIKit

final class GovernanceDelegateInfoInteractor {
    weak var presenter: GovernanceDelegateInfoInteractorOutputProtocol!
}

extension GovernanceDelegateInfoInteractor: GovernanceDelegateInfoInteractorInputProtocol {}
