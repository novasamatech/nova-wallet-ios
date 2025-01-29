import Foundation

final class MythosStkUnstakeSetupWireframe: MythosStkUnstakeSetupWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(
        from _: CollatorStkFullUnstakeSetupViewProtocol?,
        collator _: DisplayAddress
    ) {
        // TODO: Implement in separate task
    }
}
