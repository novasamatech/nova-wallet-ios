protocol SelectTracksInteractorInputProtocol: AnyObject {
    func setup()
    func retryTracksFetch()
}

protocol SelectTracksInteractorOutputProtocol: AnyObject {
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal])
    func didReceiveError(selectTracksError: SelectTracksInteractorError)
}

enum SelectTracksInteractorError: Error {
    case tracksFetchFailed(Error)
}

protocol SelectTracksPresenterProtocol: AnyObject {
    func setup()
    func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track)
    func select(group: GovernanceSelectTrackViewModel.Group)
    func proceed()
}

protocol SelectTracksViewProtocol: ControllerBackedProtocol {
    func didReceiveTracks(viewModel: GovernanceSelectTrackViewModel)
}

protocol SelectTracksWireframeProtocol: AlertPresentable, CommonRetryable, ErrorPresentable {}
