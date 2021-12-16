import Foundation
import SoraFoundation

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func proceed(view: StakingRewardDestSetupViewProtocol?, rewardDestination: RewardDestination<AccountItem>) {
        guard let confirmationView = StakingRewardDestConfirmViewFactory.createView(
            for: state,
            rewardDestination: rewardDestination
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
