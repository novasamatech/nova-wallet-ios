import Foundation
import SoraFoundation

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: AccountItem
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
