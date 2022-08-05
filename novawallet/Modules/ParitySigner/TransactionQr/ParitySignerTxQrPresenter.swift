import Foundation

final class ParitySignerTxQrPresenter {
    weak var view: ParitySignerTxQrViewProtocol?
    let wireframe: ParitySignerTxQrWireframeProtocol
    let interactor: ParitySignerTxQrInteractorInputProtocol

    init(
        interactor: ParitySignerTxQrInteractorInputProtocol,
        wireframe: ParitySignerTxQrWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrPresenterProtocol {
    func setup() {}
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrInteractorOutputProtocol {}
