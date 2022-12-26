import UIKit

final class SecurityLayerPresenter {
    weak var interactor: SecurityLayerInteractorInputProtocol?
    let wireframe: SecurityLayerWireframProtocol

    init(wireframe: SecurityLayerWireframProtocol) {
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
