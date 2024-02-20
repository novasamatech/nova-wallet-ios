protocol GovernanceTracksSettingsViewProtocol: GovernanceSelectTracksViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel)
}

protocol GovernanceTracksSettingsWireframeProtocol: GovernanceSelectTracksWireframeProtocol {
    func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        totalCount: Int
    )
}
