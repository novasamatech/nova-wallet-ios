import Foundation
import Foundation_iOS

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol?

    private var changelogs: [ReleaseChangeLog] = []
    private var lastRelease: Release?
    private var loadMoreReleaseChangeLogsTitle: LoadableViewModelState<String> = .cached(value: "")
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
            markdownText: changelog.content
        )
    }

    private func updateView() {
        if !changelogs.isEmpty {
            let viewModels = changelogs.map(convert)
            view?.didReceive(
                versionModels: viewModels,
                isCriticalBanner: releasesContainsCriticalVersion,
                isAvailableMoreVersionsModel: loadMoreReleaseChangeLogsTitle
            )
        } else if let release = lastRelease {
            let date = dateFormatter.value(for: selectedLocale).string(from: release.time)
            let model = VersionTableViewCell.Model(
                title: title(for: release),
                isLatest: true,
                severity: release.severity,
                date: date,
                markdownText: ""
            )
            view?.didReceive(
                versionModels: [model],
                isCriticalBanner: releasesContainsCriticalVersion,
                isAvailableMoreVersionsModel: loadMoreReleaseChangeLogsTitle
            )
        }
    }

    private func title(for release: Release) -> String {
        R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.inAppUpdatesVersionTitle(release.version.id)
    }

    private func handle(error: Error, retryAction: @escaping () -> Void) {
        logger?.error(error.localizedDescription)
        loadMoreReleaseChangeLogsTitle = .cached(value: loadMoreButtonText)
        updateView()

        let message = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.inAppUpdatesFetchChangeLogsError()
        let cancelAction = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonCancel()

        wireframe.presentRequestStatus(
            on: view,
            title: "",
            message: message,
            cancelAction: cancelAction,
            locale: selectedLocale,
            retryAction: retryAction
        )
    }

    private var loadMoreButtonText: String {
        R.string(preferredLanguages: selectedLocale.rLanguages).localizable.inAppUpdatesButtonShowMoreTitle()
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
        loadMoreReleaseChangeLogsTitle = .loading
        updateView()
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
                self?.loadMoreVersions()
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
        loadMoreReleaseChangeLogsTitle = .loaded(value: canLoadMoreReleaseChangeLogs ? loadMoreButtonText : "")
        lastRelease = release
        updateView()
    }

    func didReceiveLastVersion(changelog: ReleaseChangeLog) {
        changelogs = [changelog]
        updateView()
    }

    func didReceiveAllVersions(changelogs: [ReleaseChangeLog]) {
        loadMoreReleaseChangeLogsTitle = .loaded(value: "")
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
