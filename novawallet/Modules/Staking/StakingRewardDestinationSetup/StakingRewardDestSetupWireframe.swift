import Foundation
import Foundation_iOS

final class StakingRewardDestSetupWireframe: StakingRewardDestSetupWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }

    func proceed(
        view: StakingRewardDestSetupViewProtocol?,
        rewardDestination: RewardDestination<MetaChainAccountResponse>
    ) {
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
