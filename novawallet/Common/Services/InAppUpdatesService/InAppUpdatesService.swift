import SoraKeystore
import RobinHood

final class InAppUpdatesService: BaseSyncService {
    let repository: InAppUpdatesRepositoryProtocol
    let currentVersion: String
    let lastSkippedVersion: Version?
    let securityLayerService: SecurityLayerServiceProtocol
    let wireframe: InAppUpdatesServiceWireframeProtocol
    let operationManager: OperationManagerProtocol
    private var executingOperationWrapper: CompoundOperationWrapper<[Release]>?

    init(
        repository: InAppUpdatesRepositoryProtocol,
        currentVersion: String,
        settings: SettingsManagerProtocol,
        securityLayerService: SecurityLayerServiceProtocol,
        wireframe: InAppUpdatesServiceWireframeProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.currentVersion = currentVersion
        self.securityLayerService = securityLayerService
        self.wireframe = wireframe
        self.operationManager = operationManager
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

        let notInstalledVersions = releases
            .filter { $0.version > currentVersion }
            .sorted { $0.version > $1.version }

        let showUpdates = notInstalledVersions
            .contains(where: {
                isCriticalUpdate($0) || isNotInstalledMajorUpdate($0)
            })

        if showUpdates {
            DispatchQueue.main.async {
                self.wireframe.showUpdates(notInstalledVersions: notInstalledVersions)
            }
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

    private func fetchReleases() {
        let wrapper = repository.fetchReleasesWrapper()
        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let releases = try wrapper.targetOperation.extractNoCancellableResultData()
                self.showUpdatesIfNeeded(releases: releases)
                self.complete(nil)
            } catch {
                self.complete(error)
            }
            self.executingOperationWrapper = nil
        }

        executingOperationWrapper = wrapper
        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    override func performSyncUp() {
        fetchReleases()
    }

    override func stopSyncUp() {
        executingOperationWrapper?.cancel()
        executingOperationWrapper = nil
    }
}
