protocol GovernanceTracksSettingsViewProtocol: SelectTracksViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel)
}

protocol GovernanceTracksSettingsWireframeProtocol: SelectTracksWireframeProtocol {
    func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        totalCount: Int
    )
}
