import Foundation

protocol MythosClaimRewardsPresenting {
    var state: MythosStakingSharedStateProtocol { get }

    func showClaimRewards(from view: ControllerBackedProtocol?)
}

extension MythosClaimRewardsPresenting {
    func showClaimRewards(from view: ControllerBackedProtocol?) {
        guard let claimRewards = MythosStkClaimRewardsViewFactory.createView(
            for: state
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: claimRewards.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}
