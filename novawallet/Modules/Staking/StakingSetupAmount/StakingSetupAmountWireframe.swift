import Foundation
import BigInt

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func showStakingTypeSelection(
        from view: ControllerBackedProtocol?,
        method: StakingSelectionMethod,
        amount: BigUInt,
        delegate: StakingTypeDelegate?
    ) {
        guard let stakingTypeView = StakingTypeViewFactory.createView(
            state: state,
            method: method,
            amount: amount,
            delegate: delegate
        ) else {
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

    func showSelectValidators(from _: ControllerBackedProtocol?, selectedValidators _: PreparedValidators) {
        // TODO: Add validators flow adopted
    }
}
