import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorStakingSetupInteractor: SubtensorStakingDelegateBaseInteractor {
    var presenter: SubtensorStakingSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorStakingSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension SubtensorStakingSetupInteractor: SubtensorStakingSetupInteractorInputProtocol {}
