import Foundation

final class StakingMoreOptionsWireframe: StakingMoreOptionsWireframeProtocol {
    func showStartStaking(
        from view: StakingMoreOptionsViewProtocol?,
        chainAsset: ChainAsset,
        stakingType: StakingType?
    ) {
        guard let startStakingView = StartStakingInfoViewFactory.createView(
            chainAsset: chainAsset,
            selectedStakingType: stakingType
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: startStakingView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }
}
