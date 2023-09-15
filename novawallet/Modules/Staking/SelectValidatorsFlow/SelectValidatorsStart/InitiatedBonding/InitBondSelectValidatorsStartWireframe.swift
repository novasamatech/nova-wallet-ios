import Foundation

final class InitBondSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    let state: InitiatedBonding
    let stakingState: RelaychainStakingSharedStateProtocol

    init(state: InitiatedBonding, stakingState: RelaychainStakingSharedStateProtocol) {
        self.state = state
        self.stakingState = stakingState
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams
    ) {
        guard let nextView = CustomValidatorListViewFactory.createInitiatedBondingView(
            for: stakingState,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            state: state
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    override func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        guard let nextView = RecommendedValidatorListViewFactory.createInitiatedBondingView(
            stakingState: stakingState,
            validators: validatorList,
            maxTargets: maxTargets,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
