import Foundation

final class NPoolsUnstakeSetupWireframe: NPoolsUnstakeSetupWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(from _: NPoolsUnstakeSetupViewProtocol?, amount _: Decimal) {
        // TODO: Implement together with confirm screen
    }
}
