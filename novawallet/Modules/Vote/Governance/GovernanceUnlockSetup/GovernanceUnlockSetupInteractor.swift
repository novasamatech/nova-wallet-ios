import UIKit
import SubstrateSdk

final class GovernanceUnlockSetupInteractor: GovernanceUnlockInteractor {
    var presenter: GovernanceUnlockSetupInteractorOutputProtocol? {
        get {
            basePresenter as? GovernanceUnlockSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension GovernanceUnlockSetupInteractor: GovernanceUnlockSetupInteractorInputProtocol {}
