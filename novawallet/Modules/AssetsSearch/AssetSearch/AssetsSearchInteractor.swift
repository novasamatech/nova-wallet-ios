import UIKit

final class AssetsSearchInteractor: AssetListBaseInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?
}

extension AssetsSearchInteractor: AssetsSearchInteractorInputProtocol {}
