import Foundation

extension CloudBackupServiceFacade {
    static func createFacade() -> CloudBackupServiceFacadeProtocol {
        CloudBackupServiceFacade(
            serviceFactory: ICloudBackupServiceFactory(),
            operationQueue: OperationManagerFacade.cloudBackupQueue
        )
    }
}
