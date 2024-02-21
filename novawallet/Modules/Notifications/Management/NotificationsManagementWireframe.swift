import Foundation

final class NotificationsManagementWireframe: NotificationsManagementWireframeProtocol {
    func showWallets(from _: ControllerBackedProtocol?) {}

    func showStakingRewardsSetup(
        from view: ControllerBackedProtocol?,
        selectedChains: Selection<Set<ChainModel.Id>>?,
        completion: @escaping (Selection<Set<ChainModel.Id>>?) -> Void
    ) {
        guard let stakingRewardsView = StakingRewardsNotificationsViewFactory.createView(
            selectedChains: selectedChains,
            completion: completion
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            stakingRewardsView.controller,
            animated: true
        )
    }

    func showGovSetup(
        from view: ControllerBackedProtocol?,
        settings: [ChainModel.Id: GovernanceNotificationsModel],
        completion: @escaping ([ChainModel.Id: GovernanceNotificationsModel]) -> Void
    ) {
        guard let govNotificationsView = GovernanceNotificationsViewFactory.createView(
            settings: settings,
            completion: completion
        ) else {
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
