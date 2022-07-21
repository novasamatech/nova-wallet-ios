import UIKit

final class AssetsSearchInteractor: WalletListBaseInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol? {
        get {
            basePresenter as? AssetsSearchInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

extension AssetsSearchInteractor: AssetsSearchInteractorInputProtocol {}
