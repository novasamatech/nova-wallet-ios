import UIKit
import Operation_iOS
import Keystore_iOS

final class InAppUpdatesInteractor {
    weak var presenter: InAppUpdatesInteractorOutputProtocol!

    let repository: InAppUpdatesChangeLogsRepositoryProtocol
    let settings: SettingsManagerProtocol
    let securityLayerService: SecurityLayerServiceProtocol
    let versions: [Release]
    private let operationQueue: OperationQueue

    init(
        repository: InAppUpdatesChangeLogsRepositoryProtocol,
        settings: SettingsManagerProtocol,
        securityLayerService: SecurityLayerServiceProtocol,
        versions: [Release],
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.settings = settings
        self.securityLayerService = securityLayerService
        self.versions = versions.sorted {
            $0.version > $1.version
        }
        self.operationQueue = operationQueue
    }

    private func fetchLastVersionChangeLog() {
        guard let lastRelease = versions.first else {
            return
        }

        let operation = repository.fetchChangeLogOperation(for: lastRelease.version)
        operation.completionBlock = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                do {
                    let changelog = try operation.extractNoCancellableResultData()
                    self.presenter.didReceiveLastVersion(changelog: .init(
                        release: lastRelease,
                        content: changelog
                    ))
                } catch {
                    self.presenter.didReceive(error: .fetchLastVersionChangeLog(error))
                }
            }
        }
        operationQueue.addOperation(operation)
    }

    private func fetchChangeLogs() {
        let operationsMap = versions
            .reduce(into: [Release: BaseOperation<String>]()) { result, release in
                result[release] = repository.fetchChangeLogOperation(for: release.version)
            }

        let mergeOperation = ClosureOperation<[ReleaseChangeLog]> {
            try operationsMap.compactMap { release, operation in
                let content = try operation.extractNoCancellableResultData()
                return ReleaseChangeLog(release: release, content: content)
            }
        }

        let fetchOperations: [Operation] = Array(operationsMap.values)
        fetchOperations.forEach(mergeOperation.addDependency)

        mergeOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let changelogs = try mergeOperation.extractNoCancellableResultData()
                        .sorted(by: { $0.release.version > $1.release.version })
                    self?.presenter.didReceiveAllVersions(changelogs: changelogs)
                } catch {
                    self?.presenter.didReceive(error: .fetchAllChangeLogs(error))
                }
            }
        }

        operationQueue.addOperations(fetchOperations + [mergeOperation], waitUntilFinished: false)
    }
}

extension InAppUpdatesInteractor: InAppUpdatesInteractorInputProtocol {
    func setup() {
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            guard let self = self else {
                return
            }
            self.fetchLastVersionChangeLog()
            let releasesContainsCriticalVersion = self.versions.first(where: { $0.severity == .critical }) != nil
            guard let lastRelease = self.versions.first else {
                return
            }
            DispatchQueue.main.async {
                self.presenter.didReceiveLastVersion(
                    release: lastRelease,
                    releasesContainsCriticalVersion: releasesContainsCriticalVersion,
                    canLoadMoreReleaseChangeLogs: self.versions.count > 1
                )
            }
        }
    }

    func loadChangeLogs() {
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            self?.fetchChangeLogs()
        }
    }

    func skipVersion() {
        guard let lastVersion = versions.first?.version.id else {
            return
        }
        settings.skippedUpdateVersion = lastVersion
    }
}
