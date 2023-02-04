import Foundation

protocol GovernanceBaseEditDelegationViewProtocol: GovernanceSelectTracksViewProtocol {
    func didReceive(hasUnavailableTracks: Bool)
}

protocol GovernanceBaseEditDelegationPresenterProtocol: GovernanceSelectTracksPresenterProtocol {
    func showUnavailableTracks()
}

protocol GovernanceBaseEditDelegationWireframeProtocol: GovernanceSelectTracksWireframeProtocol {
    func presentUnavailableTracks(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    )
}
