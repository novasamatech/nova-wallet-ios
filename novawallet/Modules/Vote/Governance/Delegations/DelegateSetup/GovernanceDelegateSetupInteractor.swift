import UIKit

final class GovernanceDelegateSetupInteractor {
    weak var presenter: GovernanceDelegateSetupInteractorOutputProtocol?
}

extension GovernanceDelegateSetupInteractor: GovernanceDelegateSetupInteractorInputProtocol {}
