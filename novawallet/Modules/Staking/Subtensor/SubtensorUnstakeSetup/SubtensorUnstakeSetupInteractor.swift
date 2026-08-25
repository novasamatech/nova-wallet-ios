import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorUnstakeSetupInteractor: SubtensorStakingDelegateBaseInteractor {
    var presenter: SubtensorUnstakeSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeSetupInteractorInputProtocol {}
