import Foundation

extension YourValidatorList {
    final class SelectionStartWireframe: SelectValidatorsStartWireframe {
        let state: ExistingBonding
        let stakingState: StakingSharedState

        init(state: ExistingBonding, stakingState: StakingSharedState) {
            self.state = state
            self.stakingState = stakingState
        }

        override func proceedToCustomList(
            from view: ControllerBackedProtocol?,
            selectionValidatorGroups: SelectionValidatorGroups,
            selectedValidatorList: SharedList<SelectedValidatorInfo>,
            validatorsSelectionParams: ValidatorsSelectionParams
        ) {
            guard let nextView = CustomValidatorListViewFactory.createChangeYourValidatorsView(
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
            guard let nextView = RecommendedValidatorListViewFactory.createChangeYourValidatorsView(
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
}
