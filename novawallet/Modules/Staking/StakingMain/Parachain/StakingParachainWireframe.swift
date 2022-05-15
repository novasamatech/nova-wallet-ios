import Foundation

final class StakingParachainWireframe {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }
}

extension StakingParachainWireframe: StakingParachainWireframeProtocol {
    func showRewardDetails(from view: ControllerBackedProtocol?, maxReward: Decimal, avgReward: Decimal) {
        let infoVew = ModalInfoFactory.createRewardDetails(for: maxReward, avgReward: avgReward)

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
