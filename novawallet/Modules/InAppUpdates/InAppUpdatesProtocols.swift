import Foundation

protocol InAppUpdatesViewProtocol: ControllerBackedProtocol {
    func didReceive(
        versionModels: [VersionTableViewCell.Model],
        isCriticalBanner: Bool,
        isAvailableMoreVersions: Bool
    )
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
    func didReceiveLastVersion(
        release: Release,
        releasesContainsCriticalVersion: Bool,
        canLoadMoreReleaseChangeLogs: Bool
    )
    func didReceiveLastVersion(changelog: ReleaseChangeLog)
    func didReceiveAllVersions(changelogs: [ReleaseChangeLog])
}

protocol InAppUpdatesWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable {
    func finish(view: InAppUpdatesViewProtocol?)
    func show(url: URL, from view: InAppUpdatesViewProtocol?)
}
