import Foundation

final class StakingSetupProxyWireframe: StakingSetupProxyWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }

    func checkDismissing(view: ControllerBackedProtocol?) -> Bool {
        view?.controller.navigationController?.isBeingDismissed ?? true
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        proxyAddress: AccountAddress
    ) {
        guard let confirmView = StakingConfirmProxyViewFactory.createView(
            state: state,
            proxyAddress: proxyAddress,
            confirmOperation: .add
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
