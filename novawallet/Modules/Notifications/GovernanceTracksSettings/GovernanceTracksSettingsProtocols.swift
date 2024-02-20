protocol GovernanceTracksSettingsViewProtocol: GovernanceSelectTracksViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel)
}

protocol GovernanceTracksSettingsPresenterProtocol: GovernanceSelectTracksPresenterProtocol {}

protocol GovernanceTracksSettingsInteractorInputProtocol: GovernanceSelectTracksInteractorInputProtocol {}

protocol GovernanceTracksSettingsInteractorOutputProtocol: GovernanceSelectTracksInteractorOutputProtocol {}

protocol GovernanceTracksSettingsWireframeProtocol: GovernanceSelectTracksWireframeProtocol {
    func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        totalCount: Int
    )
}
