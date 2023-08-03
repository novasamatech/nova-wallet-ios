final class StartStakingInfoRelaychainWireframe: StartStakingInfoWireframe {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let setupAmountView = StakingSetupAmountViewFactory.createView(for: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(setupAmountView.controller, animated: true)
    }
}
