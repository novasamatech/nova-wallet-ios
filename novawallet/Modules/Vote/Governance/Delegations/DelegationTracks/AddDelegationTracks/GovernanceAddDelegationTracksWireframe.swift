import Foundation

final class GovernanceAddDelegationTracksWireframe: GovernanceSelectTracksWireframe,
    GovernanceBaseEditDelegationWireframeProtocol {
    let state: GovernanceSharedState
    let delegate: AccountId

    init(state: GovernanceSharedState, delegate: AccountId) {
        self.state = state
        self.delegate = delegate
    }

    func presentUnavailableTracks(
        from _: ControllerBackedProtocol?,
        votedTracks _: [GovernanceTrackInfoLocal],
        delegatedTracks _: [GovernanceTrackInfoLocal]
    ) {
        // TODO:
    }
}
