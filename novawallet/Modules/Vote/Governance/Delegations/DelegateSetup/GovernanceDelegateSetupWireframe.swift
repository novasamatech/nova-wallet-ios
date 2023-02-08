import Foundation

final class GovernanceDelegateSetupWireframe: GovernanceDelegateSetupWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showConfirm(from _: GovernanceDelegateSetupViewProtocol?, delegation _: GovernanceNewDelegation) {
        // TODO:
    }
}
