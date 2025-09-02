import Foundation
import Foundation_iOS

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
