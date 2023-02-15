protocol CommonDelegationTracksViewProtocol: ControllerBackedProtocol {
    func didReceive(tracks: [TrackTableViewCell.Model])
}

protocol CommonDelegationTracksPresenterProtocol: AnyObject {
    func setup()
}
