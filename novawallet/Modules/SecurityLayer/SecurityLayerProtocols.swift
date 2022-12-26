import UIKit

protocol SecurityLayerInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SecurityLayerInteractorOutputProtocol: AnyObject {
    func didDecideSecurePresentation()
    func didDecideUnsecurePresentation()
    func didDecideRequestAuthorization()
}

protocol SecurityLayerWireframProtocol: AnyObject {
    func showSecuringOverlay()
    func hideSecuringOverlay()
    func showAuthorization()
}
