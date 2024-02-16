import Foundation

final class NotificationsManagementWireframe: NotificationsManagementWireframeProtocol {
    func showWallets(from _: ControllerBackedProtocol?) {}

    func showStakingRewardsSetup(from view: ControllerBackedProtocol?) {
        guard let stakingRewardsView = StakingRewardsNotificationsViewFactory.createView() else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            stakingRewardsView.controller,
            animated: true
        )
    }

    func showGovSetup(from view: ControllerBackedProtocol?) {
        guard let govNotificationsView = GovernanceNotificationsViewFactory.createView() else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            govNotificationsView.controller,
            animated: true
        )
    }

    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
