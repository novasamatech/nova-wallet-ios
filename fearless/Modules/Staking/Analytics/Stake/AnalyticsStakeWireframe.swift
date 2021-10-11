import Foundation

final class AnalyticsStakeWireframe: AnalyticsStakeWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showRewardDetails(_ rewardModel: AnalyticsRewardDetailsModel, from view: ControllerBackedProtocol?) {
        guard let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(
            for: state,
            rewardModel: rewardModel
        ) else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
