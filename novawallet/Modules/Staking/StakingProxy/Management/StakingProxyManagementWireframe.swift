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

    func showRevokeProxyAccess(from view: ControllerBackedProtocol?, proxyAccount: Proxy.Account) {
        guard let confirmView = StakingRemoveProxyViewFactory.createView(
            state: state,
            proxyAccount: proxyAccount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
