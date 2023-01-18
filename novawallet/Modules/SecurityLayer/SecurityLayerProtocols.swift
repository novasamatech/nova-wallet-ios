import UIKit

protocol SecurityLayerInteractorInputProtocol: AnyObject {
    func setup()

    func completeAuthorization(for result: Bool)
}

protocol SecurityLayerInteractorOutputProtocol: AnyObject {
    func didDecideSecurePresentation()
    func didDecideUnsecurePresentation()
    func didDecideRequestAuthorization()
}

protocol SecurityLayerWireframeProtocol: AuthorizationAccessible {
    func showSecuringOverlay()
    func hideSecuringOverlay()
    func showAuthorization()
}
