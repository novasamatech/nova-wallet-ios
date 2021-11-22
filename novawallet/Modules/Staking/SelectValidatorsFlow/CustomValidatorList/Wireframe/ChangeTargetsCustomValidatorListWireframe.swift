final class ChangeTargetsCustomValidatorListWireframe: CustomValidatorListWireframe {
    let state: ExistingBonding

    init(state: ExistingBonding, stakingState: StakingSharedState) {
        self.state = state

        super.init(stakingState: stakingState)
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    ) {
        guard let nextView = SelectedValidatorListViewFactory.createChangeTargetsView(
            stakingState: stakingState,
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            state: state
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
