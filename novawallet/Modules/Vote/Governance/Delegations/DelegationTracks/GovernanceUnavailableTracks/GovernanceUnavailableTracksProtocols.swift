protocol GovernanceUnavailableTracksViewProtocol: ControllerBackedProtocol {
    func didReceive(
        votedTracks: [ReferendumInfoView.Track],
        delegatedTracks: [ReferendumInfoView.Track]
    )
}

protocol GovernanceUnavailableTracksPresenterProtocol: AnyObject {
    func setup()
    func removeVotes()
}

protocol GovernanceUnavailableTracksWireframeProtocol: AnyObject {
    func complete(on view: ControllerBackedProtocol?, completionHandler: @escaping () -> Void)
}

protocol GovernanceUnavailableTracksDelegate: AnyObject {
    func unavailableTracksDidDecideRemoveVotes()
}
