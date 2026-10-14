import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorStakingConfirmInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension SubtensorStakingConfirmInteractor: SubtensorConfirmInteractorInputProtocol {}
