import Foundation

final class InitiatedBondingRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: InitiatedBonding

    init(state: InitiatedBonding, stakingState: StakingSharedState) {
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

        guard let confirmView = SelectValidatorsConfirmViewFactory.createInitiatedBondingView(
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
