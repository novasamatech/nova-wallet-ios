import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showPayoutConfirmation(from view: ControllerBackedProtocol?, payoutInfo: PayoutInfo) {
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
