protocol GovernanceSelectTracksViewProtocol: SelectTracksViewProtocol {}

protocol GovernanceSelectTracksPresenterProtocol: SelectTracksPresenterProtocol {}

protocol GovernanceSelectTracksInteractorInputProtocol: SelectTracksInteractorInputProtocol {
    func remakeSubscriptions()
}

protocol GovernanceSelectTracksInteractorOutputProtocol: SelectTracksInteractorOutputProtocol {
    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveError(_ error: GovernanceSelectTracksInteractorError)
}

protocol GovernanceSelectTracksWireframeProtocol: SelectTracksWireframeProtocol {
    func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    )
}
