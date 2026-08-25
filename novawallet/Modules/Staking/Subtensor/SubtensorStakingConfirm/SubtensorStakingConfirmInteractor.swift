import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorStakingConfirmInteractor: SubtensorStakingSubmitInteractor {
    var presenter: SubtensorStakingConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorStakingConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension SubtensorStakingConfirmInteractor: SubtensorStakingConfirmInteractorInputProtocol {}
