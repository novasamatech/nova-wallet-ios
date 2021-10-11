import Foundation

final class ChangeTargetsSelectValidatorsStartWireframe: SelectValidatorsStartWireframe {
    let state: ExistingBonding
    let stakingState: StakingSharedState

    init(state: ExistingBonding, stakingState: StakingSharedState) {
        self.state = state
        self.stakingState = stakingState
    }

    override func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    ) {
        guard let nextView = CustomValidatorListViewFactory.createChangeTargetsView(
            for: stakingState,
            validatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
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
        guard let nextView = RecommendedValidatorListViewFactory.createChangeTargetsView(
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
