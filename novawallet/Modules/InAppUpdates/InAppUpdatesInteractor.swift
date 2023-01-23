import UIKit
import SoraKeystore

final class InAppUpdatesInteractor {
    weak var presenter: InAppUpdatesInteractorOutputProtocol!
    private let operationQueue: OperationQueue

    let repository: InAppUpdatesRepositoryProtocol
    let currentVersion: String
    let lastSkippedVersion: Version?

    init(
        repository: InAppUpdatesRepositoryProtocol,
        currentVersion: String,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationQueue = operationQueue
        self.repository = repository
        self.currentVersion = currentVersion
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
        let showUpdates = releases
            .filter { $0.version > currentVersion }
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
}

extension InAppUpdatesInteractor: InAppUpdatesInteractorInputProtocol {
    func setup() {
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
