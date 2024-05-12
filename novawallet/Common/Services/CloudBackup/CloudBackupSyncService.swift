import Foundation
import SoraKeystore
import SubstrateSdk
import RobinHood

final class CloudBackupSyncService: BaseSyncService, AnyCancellableCleaning {
    let keychain: KeystoreProtocol
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let backupOperationFactory: CloudBackupOperationFactoryProtocol
    let decodingManager: CloudBackupCoding
    let diffManager: CloudBackupDiffCalculating
    let remoteFileUrl: URL
    
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue
    
    private var wrapper: CompoundOperationWrapper<CloudBackupDiff>

    init(
        remoteFileUrl: URL,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        backupOperationFactory: CloudBackupOperationFactoryProtocol,
        decodingManager: CloudBackupCoding,
        diffManager: CloudBackupDiffCalculating,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue.global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.remoteFileUrl = remoteFileUrl
        self.walletsRepository = walletsRepository
        self.backupOperationFactory = backupOperationFactory
        self.decodingManager = decodingManager
        self.diffManager = diffManager
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        
        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    override func performSyncUp() {
        let walletsOperation = walletsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let remoteFileOperation = backupOperationFactory.createReadingOperation(for: remoteFileUrl)
        
        let decodingOperation = ClosureOperation<CloudBackup.PublicData?> {
            let data = try remoteFileOperation.extractNoCancellableResultData()
            
            return try data.map { try self.decodingManager.decode(data: $0).publicData }
        }
        
        decodingOperation.addDependency(remoteFileOperation)
        
        let diffOperation = ClosureOperation<CloudBackupDiff> {
            let wallets = try walletsOperation.extractNoCancellableResultData()
            
            guard let publicData = try decodingOperation.extractNoCancellableResultData() else {
                return []
            }
            
            return diffManager.calculateBetween(
                wallets: Set(wallets),
                publicBackupInfo: publicData
            )
        }
    }

    override func stopSyncUp() {
        clear(cancellable: &wrapper)
    }
}
