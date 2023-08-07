import Foundation

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    func showStakingTypeSelection(
        from view: ControllerBackedProtocol?,
        initialState: StakingTypeInitialState
    ) {
        guard let stakingTypeView = StakingTypeViewFactory.createView(initialState: initialState) else {
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
