import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    let subtensorFlowState: SubtensorStakingFlowStateProtocol

    init(subtensorFlowState: SubtensorStakingFlowStateProtocol) {
        self.subtensorFlowState = subtensorFlowState
    }

    func showStartStaking(
        from view: StakingMoreOptionsViewProtocol?,
        chainAsset: ChainAsset,
        stakingType: StakingType?
    ) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: stakingType,
            subtensorFlowState: subtensorFlowState
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }
}
