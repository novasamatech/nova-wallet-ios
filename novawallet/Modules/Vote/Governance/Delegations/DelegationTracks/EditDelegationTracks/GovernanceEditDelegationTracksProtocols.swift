protocol GovEditDelegationTracksWireframeProtocol: GovernanceSelectTracksWireframeProtocol {
    func presentUnavailableTracks(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    )

    func showRemoveVotes(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    )
}
