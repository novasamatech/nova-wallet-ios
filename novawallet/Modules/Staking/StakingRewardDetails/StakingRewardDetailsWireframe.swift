import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }

    func showPayoutConfirmation(from view: ControllerBackedProtocol?, payoutInfo: Staking.PayoutInfo) {
        guard
            let confirmationView = StakingPayoutConfirmationViewFactory.createView(
                for: state,
                payouts: [payoutInfo]
            ) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
