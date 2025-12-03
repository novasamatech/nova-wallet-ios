import Foundation

final class ParitySignerWelcomePresenter {
    weak var view: ParitySignerWelcomeViewProtocol?
    let wireframe: ParitySignerWelcomeWireframeProtocol
    let type: ParitySignerType

    private var selectedMode: ParitySignerWelcomeMode = .pairPublicKey

    init(wireframe: ParitySignerWelcomeWireframeProtocol, type: ParitySignerType) {
        self.wireframe = wireframe
        self.type = type
    }
}

extension ParitySignerWelcomePresenter: ParitySignerWelcomePresenterProtocol {
    func scanQr() {
        wireframe.showScanQR(from: view, type: type, mode: selectedMode)
    }

    func didSelectMode(_ mode: ParitySignerWelcomeMode) {
        selectedMode = mode
        view?.didChangeMode(mode)
    }
}
