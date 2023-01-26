import Foundation

protocol InAppUpdatesViewProtocol: ControllerBackedProtocol {
    func didReceive(versionModels: [VersionTableViewCell.Model], isAvailableMoreVersions: Bool)
    func didReceive(isCriticalBanner: Bool)
}

protocol InAppUpdatesPresenterProtocol: AnyObject {
    func setup()
    func skip()
    func loadMoreVersions()
    func installLastVersion()
}

protocol InAppUpdatesInteractorInputProtocol: AnyObject {
    func setup()
    func loadChangeLogs()
    func skipVersion()
}

protocol InAppUpdatesInteractorOutputProtocol: AnyObject {
    func didReceive(error: InAppUpdatesInteractorError)
    func didReceiveLastVersion(changelog: ReleaseChangeLog, canLoadMoreReleaseChangeLogs: Bool)
    func didReceiveAllVersions(changelogs: [ReleaseChangeLog])
    func didReceive(releasesContainsCriticalVersion: Bool)
}

protocol InAppUpdatesWireframeProtocol: AnyObject {
    func finish(view: InAppUpdatesViewProtocol?)
    func show(url: URL, from view: InAppUpdatesViewProtocol?)
}
