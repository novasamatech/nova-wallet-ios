extension YourValidatorList {
    final class SelectedListWireframe: SelectedValidatorListWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding, stakingState: RelaychainStakingSharedStateProtocol) {
            self.state = state

            super.init(stakingState: stakingState)
        }

        override func proceed(
            from view: SelectedValidatorListViewProtocol?,
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
