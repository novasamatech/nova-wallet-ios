import Foundation

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func showStakingTypeSelection(
        from view: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        method: StakingSelectionMethod
    ) {
        guard let stakingTypeView = StakingTypeViewFactory.createView(
            state: state,
            method: method
        ) else {
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
