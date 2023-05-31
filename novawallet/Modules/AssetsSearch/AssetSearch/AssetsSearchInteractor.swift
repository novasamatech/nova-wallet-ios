import UIKit

final class AssetsSearchInteractor: AssetListBaseInteractor {
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
