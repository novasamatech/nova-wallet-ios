final class InitBondingCustomValidatorListWireframe: CustomValidatorListWireframe {
    let state: InitiatedBonding

    init(
        state: InitiatedBonding,
        stakingState: RelaychainStakingSharedStateProtocol,
        lockedAddresses: Set<AccountAddress>
    ) {
        self.state = state

        super.init(stakingState: stakingState, lockedAddresses: lockedAddresses)
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    ) {
        guard let nextView = SelectedValidatorListViewFactory.createInitiatedBondingView(
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
