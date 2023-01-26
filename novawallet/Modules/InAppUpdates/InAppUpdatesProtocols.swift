protocol InAppUpdatesViewProtocol: ControllerBackedProtocol {
    func didReceive(versionModels: [VersionTableViewCell.Model])
    func didReceiveBannerState(isCritical: Bool)
}

protocol InAppUpdatesPresenterProtocol: AnyObject {
    func setup()
}

protocol InAppUpdatesInteractorInputProtocol: AnyObject {
    func setup()
    func loadChangeLogs()
}

protocol InAppUpdatesInteractorOutputProtocol: AnyObject {
    func didReceive(error: InAppUpdatesInteractorError)
    func didReceiveLastVersion(changelog: ReleaseChangeLog)
    func didReceiveAllVersions(changelogs: [ReleaseChangeLog])
    func didReceive(
        releasesContainsCriticalVersion: Bool,
        canLoadMoreReleaseChangeLogs: Bool
    )
}

protocol InAppUpdatesWireframeProtocol: AnyObject {}
