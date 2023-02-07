import Foundation

final class GovernanceDelegateSetupWireframe: GovernanceDelegateSetupWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }
}
