import UIKit

final class NPoolsUnstakeSetupInteractor: NPoolsUnstakeBaseInteractor {
    var presenter: NPoolsUnstakeSetupInteractorOutputProtocol? {
        get {
            basePresenter as? NPoolsUnstakeSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension NPoolsUnstakeSetupInteractor: NPoolsUnstakeSetupInteractorInputProtocol {}
