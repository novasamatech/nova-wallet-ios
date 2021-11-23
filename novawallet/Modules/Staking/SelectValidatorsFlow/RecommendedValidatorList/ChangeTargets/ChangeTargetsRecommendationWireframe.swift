import Foundation

final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: ExistingBonding

    init(state: ExistingBonding, stakingState: StakingSharedState) {
        self.state = state

        super.init(stakingState: stakingState)
    }

    override func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    ) {
        let nomination = PreparedNomination(
            bonding: state,
            targets: targets,
            maxTargets: maxTargets
        )

        guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeTargetsView(
            for: nomination,
            stakingState: stakingState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
