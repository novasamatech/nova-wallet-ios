import Foundation

final class ChainAddressDetailsWireframe: ChainAddressDetailsWireframeProtocol {
    func close(view: ChainAddressDetailsViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
