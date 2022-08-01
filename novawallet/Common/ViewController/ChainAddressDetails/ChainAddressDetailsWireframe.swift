import Foundation

final class ChainAddressDetailsWireframe: ChainAddressDetailsWireframeProtocol {
    func complete(view: ChainAddressDetailsViewProtocol, action: ChainAddressDetailsAction) {
        let presentingController = view.controller.presentingViewController ?? view.controller

        presentingController.dismiss(animated: true) {
            action.onSelection()
        }
    }
}
