import Foundation
import SoraFoundation

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol?

    private var changelogs: [ReleaseChangeLog] = []
    private var lastRelease: Release?
    private var canLoadMoreReleaseChangeLogs: Bool = false
    private var releasesContainsCriticalVersion: Bool = false

    init(
        interactor: InAppUpdatesInteractorInputProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        wireframe: InAppUpdatesWireframeProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.dateFormatter = dateFormatter
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func convert(changelog: ReleaseChangeLog) -> VersionTableViewCell.Model {
        let date = dateFormatter.value(for: selectedLocale).string(from: changelog.release.time)
        return VersionTableViewCell.Model(
            title: title(for: changelog.release),
            isLatest: changelog.release.version == lastRelease?.version,
            severity: changelog.release.severity,
            date: date,
            markdownText: .loaded(value: changelog.content)
        )
    }

    private func updateView() {
        if !changelogs.isEmpty {
            let viewModels = changelogs.map(convert)
            view?.didReceive(
                versionModels: viewModels,
                isCriticalBanner: releasesContainsCriticalVersion,
                isAvailableMoreVersions: canLoadMoreReleaseChangeLogs
            )
        } else if let release = lastRelease {
            let date = dateFormatter.value(for: selectedLocale).string(from: release.time)
            let model = VersionTableViewCell.Model(
                title: title(for: release),
                isLatest: true,
                severity: release.severity,
                date: date,
                markdownText: .loading
            )
            view?.didReceive(
                versionModels: [model],
                isCriticalBanner: releasesContainsCriticalVersion,
                isAvailableMoreVersions: canLoadMoreReleaseChangeLogs
            )
        }
    }

    private func title(for release: Release) -> String {
        R.string.localizable.inAppUpdatesVersionTitle(
            release.version.id,
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func handle(error: Error, retryAction: @escaping () -> Void) {
        logger?.error(error.localizedDescription)
        let message = R.string.localizable.inAppUpdatesFetchChangeLogsError(preferredLanguages: selectedLocale.rLanguages)
        let cancelAction = R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)

        wireframe.presentRequestStatus(
            on: view,
            title: "",
            message: message,
            cancelAction: cancelAction,
            locale: selectedLocale,
            retryAction: retryAction
        )
    }
}

extension InAppUpdatesPresenter: InAppUpdatesPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func skip() {
        interactor.skipVersion()
        wireframe.finish(view: view)
    }

    func loadMoreVersions() {
        interactor.loadChangeLogs()
    }

    func installLastVersion() {
        wireframe.show(
            url: applicationConfig.appStoreURL,
            from: view
        )
    }
}

extension InAppUpdatesPresenter: InAppUpdatesInteractorOutputProtocol {
    func didReceive(error: InAppUpdatesInteractorError) {
        switch error {
        case let .fetchAllChangeLogs(error):
            handle(error: error, retryAction: { [weak self] in
                self?.interactor.loadChangeLogs()
            })
        case let .fetchLastVersionChangeLog(error):
            handle(error: error, retryAction: { [weak self] in
                self?.interactor.setup()
            })
        }
    }

    func didReceiveLastVersion(
        release: Release,
        releasesContainsCriticalVersion: Bool,
        canLoadMoreReleaseChangeLogs: Bool
    ) {
        self.releasesContainsCriticalVersion = releasesContainsCriticalVersion
        self.canLoadMoreReleaseChangeLogs = canLoadMoreReleaseChangeLogs
        lastRelease = release
        updateView()
    }

    func didReceiveLastVersion(changelog: ReleaseChangeLog) {
        changelogs = [changelog]
        updateView()
    }

    func didReceiveAllVersions(changelogs: [ReleaseChangeLog]) {
        canLoadMoreReleaseChangeLogs = false
        self.changelogs = changelogs
        updateView()
    }
}

extension InAppUpdatesPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
