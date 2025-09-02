final class StakingBondMoreConfirmationWireframe: StakingBondMoreConfirmationWireframeProtocol {
    let state: RelaychainStakingSharedStateProtocol

    init(state: RelaychainStakingSharedStateProtocol) {
        self.state = state
    }
}
