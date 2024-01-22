import Foundation

final class StakingProxyManagementWireframe: StakingProxyManagementWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }

    func showAddProxy(from view: ControllerBackedProtocol?) {
        guard let setupProxyView = StakingSetupProxyViewFactory.createView(state: state) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            setupProxyView.controller,
            animated: true
        )
    }

    func showRevokeProxyAccess(from view: ControllerBackedProtocol?, proxyAddress: AccountAddress) {
        guard let confirmView = StakingRemoveProxyViewFactory.createView(
            state: state,
            proxyAddress: proxyAddress
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
