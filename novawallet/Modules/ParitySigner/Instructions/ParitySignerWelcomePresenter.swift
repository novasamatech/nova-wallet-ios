import Foundation

final class ParitySignerWelcomePresenter {
    weak var view: ParitySignerWelcomeViewProtocol?
    let wireframe: ParitySignerWelcomeWireframeProtocol
    let type: ParitySignerType

    init(wireframe: ParitySignerWelcomeWireframeProtocol, type: ParitySignerType) {
        self.wireframe = wireframe
        self.type = type
    }
}

extension ParitySignerWelcomePresenter: ParitySignerWelcomePresenterProtocol {
    func scanQr() {
        wireframe.showScanQR(from: view, type: type)
    }
}

extension ParitySignerWelcomePresenter: ParitySignerWelcomeInteractorOutputProtocol {}
