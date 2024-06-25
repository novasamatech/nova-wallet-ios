import Foundation
import SoraFoundation

class WalletImportOptionsPresenter {
    weak var view: WalletImportOptionsViewProtocol?

    func provideViewModel() {
        fatalError("Must be overriden by subsclass")
    }
}

extension WalletImportOptionsPresenter: WalletImportOptionsPresenterProtocol {
    func setup() {
        provideViewModel()
    }
}
