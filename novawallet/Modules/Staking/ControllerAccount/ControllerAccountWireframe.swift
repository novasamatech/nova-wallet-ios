import Foundation
import Foundation_iOS

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: MetaChainAccountResponse
    ) {
        guard let confirmation = ControllerAccountConfirmationViewFactory.createView(
            for: state,
            controllerAccountItem: controllerAccountItem
        ) else { return }
        view?.controller.navigationController?.pushViewController(confirmation.controller, animated: true)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
