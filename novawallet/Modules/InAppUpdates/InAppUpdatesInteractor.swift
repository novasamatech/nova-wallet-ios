import UIKit
import RobinHood
import SoraKeystore

final class InAppUpdatesInteractor {
    weak var presenter: InAppUpdatesInteractorOutputProtocol!

    let repository: InAppUpdatesRepositoryProtocol
    let settings: SettingsManagerProtocol
    let securityLayerService: SecurityLayerServiceProtocol
    let versions: [Release]
    private let operationQueue: OperationQueue

    init(
        repository: InAppUpdatesRepositoryProtocol,
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
            DispatchQueue.main.async {
                do {
                    let changelog = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveLastVersion(changelog: .init(
                        release: lastRelease,
                        content: changelog
                    ))
                } catch {
                    self?.presenter.didReceive(error: .fetchLastVersionChangeLog(error))
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

        let mergeOperation = ClosureOperation<[ChangeLog]> {
            try operationsMap.compactMap { release, operation in
                let content = try operation.extractNoCancellableResultData()
                return ChangeLog(release: release, content: content)
            }
        }

        var fetchOperations: [Operation] = []
        operationsMap.values.forEach {
            mergeOperation.addDependency($0)
            fetchOperations.append($0)
        }

        mergeOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let changelogs = try mergeOperation.extractNoCancellableResultData()
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
            DispatchQueue.main.async {
                let releasesContainsCriticalVersion = self.versions.first(where: { $0.severity == .critical }) != nil
                self.presenter.didReceive(
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
}
