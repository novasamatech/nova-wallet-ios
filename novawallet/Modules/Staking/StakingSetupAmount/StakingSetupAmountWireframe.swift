import Foundation

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func showStakingTypeSelection(from view: ControllerBackedProtocol?) {
        guard let stakingTypeView = StakingTypeViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakingTypeView.controller,
            animated: true
        )
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        stakingOption: SelectedStakingOption,
        amount: Decimal
    ) {
        guard
            let confirmationView = StartStakingConfirmViewFactory.createView(
                for: stakingOption,
                amount: amount,
                state: state
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
