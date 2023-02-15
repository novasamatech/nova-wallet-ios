protocol CommonDelegationTracksViewProtocol: ControllerBackedProtocol {
    func didReceive(tracks: [TrackTableViewCell.Model])
    func didReceive(title: String)
}

protocol CommonDelegationTracksPresenterProtocol: AnyObject {
    func setup()
}
