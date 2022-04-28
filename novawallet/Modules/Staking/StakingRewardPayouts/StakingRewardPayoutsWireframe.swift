import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        historyDepth: UInt32,
        eraCountdown: EraCountdown
    ) {
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            historyDepth: historyDepth,
            eraCountdown: eraCountdown
        )
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(for: state, input: input)
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }

    func showPayoutConfirmation(for payouts: [PayoutInfo], from view: ControllerBackedProtocol?) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory
            .createView(for: state, payouts: payouts) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
