import Foundation

final class NotificationsManagementWireframe: NotificationsManagementWireframeProtocol {
    func showWallets(
        from view: ControllerBackedProtocol?,
        initState: [Web3AlertWallet]?,
        completion: @escaping ([Web3AlertWallet]) -> Void
    ) {
        guard let walletsView = NotificationWalletListViewFactory.createView(
            initState: initState,
            completion: completion
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            walletsView.controller,
            animated: true
        )
    }

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
        settings: GovernanceNotificationsInitModel?,
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
