import Foundation
import Keystore_iOS
import Operation_iOS

final class InAppUpdatesService: BaseSyncService, AnyCancellableCleaning {
    let repository: InAppUpdatesReleasesRepositoryProtocol
    let currentVersion: String
    let securityLayerService: SecurityLayerServiceProtocol
    let wireframe: InAppUpdatesServiceWireframeProtocol
    let operationManager: OperationManagerProtocol
    let sessionStorage: SessionStorageProtocol
    let settings: SettingsManagerProtocol

    @Atomic(defaultValue: nil) private var executingOperation: CancellableCall?

    init(
        repository: InAppUpdatesReleasesRepositoryProtocol,
        currentVersion: String,
        settings: SettingsManagerProtocol,
        sessionStorage: SessionStorageProtocol,
        securityLayerService: SecurityLayerServiceProtocol,
        wireframe: InAppUpdatesServiceWireframeProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.currentVersion = currentVersion
        self.securityLayerService = securityLayerService
        self.wireframe = wireframe
        self.operationManager = operationManager
        self.sessionStorage = sessionStorage
        self.settings = settings
    }

    private func showUpdatesIfNeeded(releases: [Release]) {
        guard let currentVersion = ReleaseVersion.parse(from: currentVersion) else {
            return
        }
        let lastSkippedVersion = settings.skippedUpdateVersion.map(ReleaseVersion.parse) ?? nil

        let notInstalledVersions = releases
            .filter { $0.version > currentVersion }
            .sorted { $0.version > $1.version }

        let showUpdates = notInstalledVersions
            .contains(where: {
                isCriticalUpdate($0) || isNotInstalledMajorUpdate($0, lastSkippedVersion: lastSkippedVersion)
            })

        if showUpdates {
            DispatchQueue.main.async {
                self.sessionStorage.inAppUpdatesWasShown = true
                self.wireframe.showUpdates(notInstalledVersions: notInstalledVersions)
            }
        }
    }

    private func isCriticalUpdate(_ release: Release) -> Bool {
        release.severity == .critical
    }

    private func isNotInstalledMajorUpdate(
        _ release: Release,
        lastSkippedVersion: ReleaseVersion?
    ) -> Bool {
        guard release.severity == .major else {
            return false
        }
        guard let lastSkippedVersion = lastSkippedVersion else {
            return true
        }
        return release.version > lastSkippedVersion
    }

    private func fetchReleases() {
        let wrapper = repository.fetchReleasesWrapper()
        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, self.executingOperation === wrapper else {
                return
            }
            self.executingOperation = nil
            do {
                let releases = try wrapper.targetOperation.extractNoCancellableResultData()
                self.showUpdatesIfNeeded(releases: releases)
                self.complete(nil)
            } catch {
                self.complete(error)
            }
        }

        executingOperation = wrapper
        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    private func finishWithoutSync() {
        let emptyOperation = ClosureOperation<[Release]>.createWithResult([])
        let wrapper = CompoundOperationWrapper(targetOperation: emptyOperation)
        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, self.executingOperation === wrapper else {
                return
            }
            self.executingOperation = nil
            self.complete(nil)
        }
        executingOperation = wrapper
        operationManager.enqueue(
            operations: [wrapper.targetOperation],
            in: .transient
        )
    }

    override func performSyncUp() {
        securityLayerService.scheduleExecutionIfAuthorized { [weak self] in
            guard let self = self else {
                return
            }
            if self.sessionStorage.inAppUpdatesWasShown {
                self.finishWithoutSync()
            } else {
                self.fetchReleases()
            }
        }
    }

    override func stopSyncUp() {
        clear(cancellable: &executingOperation)
    }
}
