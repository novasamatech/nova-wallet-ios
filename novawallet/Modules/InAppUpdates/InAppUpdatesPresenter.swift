import Foundation
import SoraFoundation

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let applicationConfig: ApplicationConfigProtocol

    private var latestReleaseChangelog: ReleaseChangeLog?
    private var releases: [ReleaseChangeLog]?
    private var canLoadMoreReleaseChangeLogs: Bool = false

    init(
        interactor: InAppUpdatesInteractorInputProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        wireframe: InAppUpdatesWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.dateFormatter = dateFormatter
        self.applicationConfig = applicationConfig
        self.localizationManager = localizationManager
    }

    private func convert(changelog: ReleaseChangeLog) -> VersionTableViewCell.Model {
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
            view?.didReceive(versionModels: viewModels, isAvailableMoreVersions: false)
        } else if let latestRelease = latestReleaseChangelog {
            view?.didReceive(
                versionModels: [convert(changelog: latestRelease)],
                isAvailableMoreVersions: canLoadMoreReleaseChangeLogs
            )
        }
    }
}

extension InAppUpdatesPresenter: InAppUpdatesPresenterProtocol {
    func skip() {
        interactor.skipVersion()
        wireframe.finish(view: view)
    }

    func loadMoreVersions() {
        interactor.loadChangeLogs()
    }

    func setup() {
        interactor.setup()
    }
}

extension InAppUpdatesPresenter: InAppUpdatesInteractorOutputProtocol {
    func didReceive(error _: InAppUpdatesInteractorError) {
        // TODO:
    }

    func didReceive(
        releasesContainsCriticalVersion: Bool
    ) {
        view?.didReceive(isCriticalBanner: releasesContainsCriticalVersion)
    }

    func didReceiveLastVersion(changelog: ReleaseChangeLog, canLoadMoreReleaseChangeLogs: Bool) {
        latestReleaseChangelog = changelog
        self.canLoadMoreReleaseChangeLogs = canLoadMoreReleaseChangeLogs
        view?.didReceive(
            versionModels: [convert(changelog: changelog)],
            isAvailableMoreVersions: canLoadMoreReleaseChangeLogs
        )
    }

    func didReceiveAllVersions(changelogs: [ReleaseChangeLog]) {
        releases = changelogs
        let viewModels = changelogs.map(convert)
        view?.didReceive(versionModels: viewModels, isAvailableMoreVersions: false)
    }

    func installLastVersion() {
        wireframe.show(
            url: applicationConfig.appStoreURL,
            from: view
        )
    }
}

extension InAppUpdatesPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
