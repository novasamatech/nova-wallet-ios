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

    func showSelectValidators(
        from view: ControllerBackedProtocol?,
        selectedValidators: PreparedValidators,
        delegate: StakingSetupTypeEntityFacade
    ) {
        let selectionValidatorGroups = SelectionValidatorGroups(
            fullValidatorList: selectedValidators.electedValidators.map { $0.toSelected(for: nil) },
            recommendedValidatorList: selectedValidators.recommendedValidators
        )

        let hasIdentity = selectedValidators.electedValidators.contains { $0.hasIdentity }
        let validatorsSelectionParams = ValidatorsSelectionParams(
            maxNominations: selectedValidators.maxTargets,
            hasIdentity: hasIdentity
        )

        guard let validatorsView = CustomValidatorListViewFactory.createValidatorListView(
            for: state,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: SharedList(items: selectedValidators.targets),
            validatorsSelectionParams: validatorsSelectionParams,
            delegate: delegate
        ) else {
            return
        }

        delegate.bindToFlow(controller: validatorsView.controller)

        view?.controller.navigationController?.pushViewController(
            validatorsView.controller,
            animated: true
        )
    }
}
