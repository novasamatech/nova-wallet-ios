extension YourValidatorList {
    final class RecommendationWireframe: RecommendedValidatorListWireframe {
        private let state: ExistingBonding

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

            guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeYourValidatorsView(
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
}
