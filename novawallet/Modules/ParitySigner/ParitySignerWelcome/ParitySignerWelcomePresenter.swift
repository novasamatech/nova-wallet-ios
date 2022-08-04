import Foundation

final class ParitySignerWelcomePresenter {
    weak var view: ParitySignerWelcomeViewProtocol?
    let wireframe: ParitySignerWelcomeWireframeProtocol

    init(wireframe: ParitySignerWelcomeWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension ParitySignerWelcomePresenter: ParitySignerWelcomePresenterProtocol {
    func scanQr() {
        // TODO: Show qr scaner and handle result
    }
}

extension ParitySignerWelcomePresenter: ParitySignerWelcomeInteractorOutputProtocol {}
