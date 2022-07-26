import Foundation

final class WalletSelectionPresenter {
    weak var view: WalletSelectionViewProtocol?
    let wireframe: WalletSelectionWireframeProtocol
    let interactor: WalletSelectionInteractorInputProtocol

    init(
        interactor: WalletSelectionInteractorInputProtocol,
        wireframe: WalletSelectionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletSelectionPresenter: WalletSelectionPresenterProtocol {
    func setup() {}
}

extension WalletSelectionPresenter: WalletSelectionInteractorOutputProtocol {}