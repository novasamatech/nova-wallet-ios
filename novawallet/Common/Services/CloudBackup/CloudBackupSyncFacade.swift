import Foundation

protocol CloudBackupSyncFacadeProtocol: ApplicationServiceProtocol {
    var isCloudBackupEnabled: Bool { get }

    func enableBackup(
        for password: String,
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )

    func disableBackup(
        runCompletionIn queue: DispatchQueue,
        completionClosure: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    )
}

final class CloudBackupSyncFacade {
    let syncMetadataManaging: CloudBackupSyncMetadataManaging
    let serviceFactory: CloudBackupServiceFactoryProtocol
    let operationQueue: OperationQueue

    private var syncService: SyncServiceProtocol?
    private var remoteMonitor: CloudBackupUpdateMonitoring?

    init(
        syncMetadataManaging: CloudBackupSyncMetadataManaging,
        serviceFactory: CloudBackupServiceFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.syncMetadataManaging = syncMetadataManaging
        self.serviceFactory = serviceFactory
        self.operationQueue = operationQueue
    }
}

extension CloudBackupSyncFacade: CloudBackupSyncFacadeProtocol {
    var isCloudBackupEnabled: Bool {
        syncMetadataManaging.isBackupEnabled
    }

    func enableBackup(
        for _: String,
        runCompletionIn _: DispatchQueue,
        completionClosure _: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    ) {}

    func disableBackup(
        runCompletionIn _: DispatchQueue,
        completionClosure _: @escaping (Result<Void, CloudBackupServiceFacadeError>) -> Void
    ) {}

    func setup() {}

    func throttle() {}
}
