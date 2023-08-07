import Foundation

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    func showStakingTypeSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        method: StakingSelectionMethod
    ) {
        guard let stakingTypeView = StakingTypeViewFactory.createView(chainAsset: chainAsset, method: method) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakingTypeView.controller,
            animated: true
        )
    }

    func showConfirmation(from _: ControllerBackedProtocol?, stakingOption _: SelectedStakingOption) {
        // TODO: Implement confirmation
    }
}
