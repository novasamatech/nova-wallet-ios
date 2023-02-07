import UIKit

final class GovernanceDelegateSetupInteractor: GovernanceDelegateInteractor {
    var presenter: GovernanceDelegateSetupInteractorOutputProtocol? {
        get {
            basePresenter as? GovernanceDelegateSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension GovernanceDelegateSetupInteractor: GovernanceDelegateSetupInteractorInputProtocol {}
