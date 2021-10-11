import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        erasPerDay: UInt32
    ) {
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            activeEra: activeEra,
            historyDepth: historyDepth,
            erasPerDay: erasPerDay
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
