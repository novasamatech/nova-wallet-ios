import UIKit

final class SecurityLayerPresenter {
    weak var interactor: SecurityLayerInteractorInputProtocol?
    let wireframe: SecurityLayerWireframeProtocol

    init(wireframe: SecurityLayerWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension SecurityLayerPresenter: SecurityLayerInteractorOutputProtocol {
    func didDecideSecurePresentation() {
        wireframe.showSecuringOverlay()
    }

    func didDecideUnsecurePresentation() {
        wireframe.hideSecuringOverlay()
    }

    func didDecideRequestAuthorization() {
        wireframe.showAuthorization()
    }
}
