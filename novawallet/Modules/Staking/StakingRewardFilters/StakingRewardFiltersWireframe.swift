import Foundation

final class StakingRewardFiltersWireframe: StakingRewardFiltersWireframeProtocol {
    func close(view: StakingRewardFiltersViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
