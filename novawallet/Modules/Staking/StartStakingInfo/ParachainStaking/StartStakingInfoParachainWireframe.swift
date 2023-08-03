final class StartStakingInfoParachainWireframe: StartStakingInfoWireframe {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let stakeView = ParaStkStakeSetupViewFactory.createView(
            with: state,
            initialDelegator: nil,
            initialScheduledRequests: nil,
            delegationIdentities: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakeView.controller,
            animated: true
        )
    }
}
