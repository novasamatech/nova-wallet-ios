import Foundation
import SoraFoundation

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol
    let dateFormatter = DateFormatter.shortDate
    private var latestReleaseChangelog: ChangeLog?
    private var releases: [ChangeLog]?

    init(
        interactor: InAppUpdatesInteractorInputProtocol,
        localizationManager: LocalizationManagerProtocol,
        wireframe: InAppUpdatesWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func convert(changelog: ChangeLog) -> VersionTableViewCell.Model {
        let date = dateFormatter.value(for: selectedLocale).string(from: changelog.release.time)
        return VersionTableViewCell.Model(
            title: changelog.release.version.id,
            isLatest: changelog.release.version == latestReleaseChangelog?.release.version,
            severity: changelog.release.severity,
            date: date,
            markdownText: changelog.content
        )
    }

    private func updateView() {
        if let releases = releases {
            let viewModels = releases.map(convert)
            view?.didReceive(versionModels: viewModels)
        } else if let latestRelease = latestReleaseChangelog {
            view?.didReceive(versionModels: [convert(changelog: latestRelease)])
        }
    }
}

extension InAppUpdatesPresenter: InAppUpdatesPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension InAppUpdatesPresenter: InAppUpdatesInteractorOutputProtocol {
    func didReceive(error _: InAppUpdatesInteractorError) {
        print("Error")
    }

    func didReceive(
        releasesContainsCriticalVersion: Bool,
        canLoadMoreReleaseChangeLogs _: Bool
    ) {
        view?.didReceiveBannerState(isCritical: releasesContainsCriticalVersion)
    }

    func didReceiveLastVersion(changelog: ChangeLog) {
        latestReleaseChangelog = changelog
        view?.didReceive(versionModels: [convert(changelog: changelog)])
    }

    func didReceiveAllVersions(changelogs: [ChangeLog]) {
        releases = changelogs
        let viewModels = changelogs.map(convert)
        view?.didReceive(versionModels: viewModels)
    }
}

extension InAppUpdatesPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
