import Foundation

extension CloudBackupServiceFacade {
    static func createFacade() -> CloudBackupServiceFacadeProtocol {
        let cloudQueue = OperationManagerFacade.cloudBackupQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: cloudQueue)

        return CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: cloudQueue
        )
    }
}
