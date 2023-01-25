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
    func didReceiveLastVersion(changelog: ChangeLog)
    func didReceiveAllVersions(changelogs: [ChangeLog])
    func didReceive(
        releasesContainsCriticalVersion: Bool,
        canLoadMoreReleaseChangeLogs: Bool
    )
}

protocol InAppUpdatesWireframeProtocol: AnyObject {}
