final class StartStakingInfoParachainWireframe: StartStakingInfoWireframe {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from _: ControllerBackedProtocol?) {}
}
