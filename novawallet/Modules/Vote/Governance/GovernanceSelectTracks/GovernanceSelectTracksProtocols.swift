protocol GovernanceSelectTracksViewProtocol: ControllerBackedProtocol {
    func didReceiveTracks(viewModel: GovernanceSelectTrackViewModel)
}

protocol GovernanceSelectTracksPresenterProtocol: AnyObject {
    func setup()
    func select(track: GovernanceSelectTrackViewModel.Track)
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

protocol GovernanceSelectTracksWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {}
