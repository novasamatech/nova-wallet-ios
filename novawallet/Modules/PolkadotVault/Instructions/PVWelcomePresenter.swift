import Foundation

final class PVWelcomePresenter {
    weak var view: PVWelcomeViewProtocol?
    let wireframe: PVWelcomeWireframeProtocol
    let type: ParitySignerType

    private var selectedMode: PVWelcomeMode = .pairPublicKey

    init(
        wireframe: PVWelcomeWireframeProtocol,
        type: ParitySignerType
    ) {
        self.wireframe = wireframe
        self.type = type
    }
}

extension PVWelcomePresenter: PVWelcomePresenterProtocol {
    func scanQr() {
        wireframe.showScanQR(from: view, type: type)
    }

    func didSelectMode(_ mode: PVWelcomeMode) {
        selectedMode = mode
        view?.didChangeMode(mode)
    }
}
