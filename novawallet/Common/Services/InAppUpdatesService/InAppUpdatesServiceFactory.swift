import SoraKeystore

protocol InAppUpdatesServiceFactoryProtocol {
    func createService() -> SyncServiceProtocol
}

final class InAppUpdatesServiceFactory: InAppUpdatesServiceFactoryProtocol {
    func createService() -> SyncServiceProtocol {
        let urlProvider = InAppUpdatesUrlProvider(applicationConfig: ApplicationConfig.shared)

        return InAppUpdatesService(
            repository: InAppUpdatesRepository(urlProvider: urlProvider),
            currentVersion: ApplicationConfig.shared.version,
            settings: SettingsManager.shared,
            securityLayerService: SecurityLayerService.shared,
            wireframe: InAppUpdatesServiceWireframe(),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
