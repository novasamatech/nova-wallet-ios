import Foundation

final class ParitySignerUpdateWalletPresenter {
    weak var view: ParitySignerUpdateWalletViewProtocol?
    let wireframe: ParitySignerUpdateWalletWireframeProtocol
    let interactor: ParitySignerUpdateWalletInteractorInputProtocol

    init(
        interactor: ParitySignerUpdateWalletInteractorInputProtocol,
        wireframe: ParitySignerUpdateWalletWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParitySignerUpdateWalletPresenter: ParitySignerUpdateWalletPresenterProtocol {
    func setup() {}
}

extension ParitySignerUpdateWalletPresenter: ParitySignerUpdateWalletInteractorOutputProtocol {}