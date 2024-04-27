import Foundation

final class WalletImportOptionsPresenter {
    weak var view: WalletImportOptionsViewProtocol?
    let wireframe: WalletImportOptionsWireframeProtocol
    let interactor: WalletImportOptionsInteractorInputProtocol

    init(
        interactor: WalletImportOptionsInteractorInputProtocol,
        wireframe: WalletImportOptionsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletImportOptionsPresenter: WalletImportOptionsPresenterProtocol {
    func setup() {}
}

extension WalletImportOptionsPresenter: WalletImportOptionsInteractorOutputProtocol {}
