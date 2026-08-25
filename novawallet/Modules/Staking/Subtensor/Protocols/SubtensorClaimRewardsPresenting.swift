import Foundation

protocol SubtensorClaimRewardsPresenting {
    var state: SubtensorStakingSharedStateProtocol { get }

    func showClaimRewards(from view: ControllerBackedProtocol?)
}

extension SubtensorClaimRewardsPresenting {
    func showClaimRewards(from view: ControllerBackedProtocol?) {
        guard let claimRewards = SubtensorClaimRewardsViewFactory.createView(
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
