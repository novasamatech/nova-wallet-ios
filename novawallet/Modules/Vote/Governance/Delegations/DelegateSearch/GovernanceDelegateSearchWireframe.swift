import Foundation

final class GovernanceDelegateSearchWireframe: GovernanceDelegateSearchWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }
}
