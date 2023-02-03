protocol GovernanceSelectTracksViewProtocol: ControllerBackedProtocol {
    func didReceiveTracks(viewModel: GovernanceSelectTrackViewModel)
}

protocol GovernanceSelectTracksPresenterProtocol: AnyObject {
    func setup()
    func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track)
    func select(group: GovernanceSelectTrackViewModel.Group)
    func proceed()
}

protocol GovernanceSelectTracksInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func retryTracksFetch()
}

protocol GovernanceSelectTracksInteractorOutputProtocol: AnyObject {
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal])
    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveError(_ error: GovernanceSelectTracksInteractorError)
}

protocol GovernanceSelectTracksWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    )
}
