import Foundation

final class GovRevokeDelegationConfirmWireframe: GovernanceRevokeDelegationConfirmWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showTracks(from _: GovernanceRevokeDelegationConfirmViewProtocol?, tracks _: [GovernanceTrackInfoLocal]) {}

    func complete(on _: GovernanceRevokeDelegationConfirmViewProtocol?, locale _: Locale) {}
}
