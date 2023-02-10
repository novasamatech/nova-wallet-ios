import Foundation

final class GovernanceYourDelegationsWireframe: GovernanceYourDelegationsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }
}
