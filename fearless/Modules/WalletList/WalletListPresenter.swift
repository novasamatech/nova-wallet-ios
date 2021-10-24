import Foundation

final class WalletListPresenter {
    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol

    init(
        interactor: WalletListInteractorInputProtocol,
        wireframe: WalletListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {}
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {}