import UIKit
import RobinHood
import SoraKeystore

final class InAppUpdatesInteractor {
    weak var presenter: InAppUpdatesInteractorOutputProtocol!
    private let operationQueue: OperationQueue

    let repository: InAppUpdatesRepositoryProtocol
    let currentVersion: String
    let lastSkippedVersion: Version?
    let securityLayerService: SecurityLayerServiceProtocol
    private var notInstalledVersions: [Release] = []

    init(
        repository: InAppUpdatesRepositoryProtocol,
        currentVersion: String,
        settings: SettingsManagerProtocol,
        securityLayerService: SecurityLayerServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationQueue = operationQueue
        self.repository = repository
        self.currentVersion = currentVersion
        self.securityLayerService = securityLayerService

        if let lastSkippedUpdateVersion = settings.skippedUpdateVersion {
            lastSkippedVersion = Version.parse(from: lastSkippedUpdateVersion)
        } else {
            lastSkippedVersion = nil
        }
    }

    private func showUpdatesIfNeeded(releases: [Release]) {
        guard let currentVersion = Version.parse(from: currentVersion) else {
            return
        }

        notInstalledVersions = releases
            .filter { $0.version > currentVersion }
            .sorted { $0.version > $1.version }
        let showUpdates = notInstalledVersions
            .contains(where: {
                isCriticalUpdate($0) || isNotInstalledMajorUpdate($0)
            })

        if showUpdates {
            // presenter show updates
        }
    }

    private func isCriticalUpdate(_ release: Release) -> Bool {
        release.severity == .critical
    }

    private func isNotInstalledMajorUpdate(_ release: Release) -> Bool {
        guard release.severity == .major else {
            return false
        }
        guard let lastSkippedVersion = lastSkippedVersion else {
            return true
        }
        return release.version > lastSkippedVersion
    }

    private func fetchChangeLog(for version: Version) {
        let operation = repository.fetchChangeLogOperation(for: version)
        operation.completionBlock = { [weak self] in
            do {
                let changelog = try operation.extractNoCancellableResultData()
                // presenter.didReceive(for: version, changelog: changelog)
            } catch {
                // presenter.didReceive(error: Error)
            }
        }
        operationQueue.addOperation(operation)
    }

    private func fetchChangeLogs(versions: [Version]) {
        let operationsMap = versions.reduce(into: [Version: BaseOperation<String>]()) { result, version in
            result[version] = repository.fetchChangeLogOperation(for: version)
        }

        let mergeOperation = ClosureOperation<[ChangeLog]> {
            operationsMap.compactMap { version, operation in
                guard let content = try? operation.extractNoCancellableResultData() else {
                    return nil
                }
                return ChangeLog(version: version, content: content)
            }
        }

        var fetchOperations: [Operation] = []
        operationsMap.values.forEach {
            mergeOperation.addDependency($0)
            fetchOperations.append($0)
        }

        mergeOperation.completionBlock = { [weak self] in
            do {
                let changelog = try mergeOperation.extractNoCancellableResultData()
                // presenter.didReceive(for: version, changelog: changelog)
            } catch {
                // presenter.didReceive(error: Error)
            }
        }

        operationQueue.addOperations(fetchOperations + [mergeOperation], waitUntilFinished: false)
    }

    private func fetchReleases() {
        let wrapper = repository.fetchReleasesWrapper()
        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let releases = try? wrapper.targetOperation.extractNoCancellableResultData() else {
                // show error
                return
            }
            self?.showUpdatesIfNeeded(releases: releases)
        }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension InAppUpdatesInteractor: InAppUpdatesInteractorInputProtocol {
    func setup() {
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            self?.fetchReleases()
        }
    }

    func loadLastVersionChangeLog() {
        guard let lastRelease = notInstalledVersions.first else {
            return
        }
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            self?.fetchChangeLog(for: lastRelease.version)
        }
    }

    func loadAllChangeLogs() {
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            guard let self = self else {
                return
            }
            self.fetchChangeLogs(versions: self.notInstalledVersions.map(\.version))
        }
    }
}
