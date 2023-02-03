import Foundation

final class GovernanceAddDelegationTracksWireframe: GovernanceSelectTracksWireframe,
    GovernanceBaseEditDelegationWireframeProtocol {
    let state: GovernanceSharedState
    let delegateId: AccountId

    init(state: GovernanceSharedState, delegate: AccountId) {
        self.state = state
        delegateId = delegate
    }

    func presentUnavailableTracks(
        from _: ControllerBackedProtocol?,
        votedTracks _: [GovernanceTrackInfoLocal],
        delegatedTracks _: [GovernanceTrackInfoLocal]
    ) {
        // TODO: #860pmdtgx
    }
}
