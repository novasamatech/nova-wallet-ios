import Foundation

final class StakingSetupProxyWireframe: StakingSetupProxyWireframeProtocol {
    func checkDismissing(view: ControllerBackedProtocol?) -> Bool {
        view?.controller.navigationController?.isBeingDismissed ?? true
    }

    func showConfirmation(
        from _: ControllerBackedProtocol?,
        proxyAddress _: AccountAddress
    ) {
        // TODO: Confirm screen
    }
}
