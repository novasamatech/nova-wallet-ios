import Foundation

protocol MythosClaimRewardsPresenting {
    var state: MythosStakingSharedStateProtocol { get }

    func showClaimRewards(from view: ControllerBackedProtocol?)
}

extension MythosClaimRewardsPresenting {
    func showClaimRewards(from _: ControllerBackedProtocol?) {
        // TODO: Implement with claiming rewards logic
    }
}
