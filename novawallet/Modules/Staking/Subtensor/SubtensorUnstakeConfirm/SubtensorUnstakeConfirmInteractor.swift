import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorUnstakeConfirmInteractor: SubtensorStakingSubmitInteractor {
    var presenter: SubtensorUnstakeConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension SubtensorUnstakeConfirmInteractor: SubtensorUnstakeConfirmInteractorInputProtocol {}
