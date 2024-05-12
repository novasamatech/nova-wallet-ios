import Foundation
import RobinHood
import SoraKeystore
import IrohaCrypto

enum CloudBackupSyncResult {
    struct State {
        let localWallets: Set<MetaAccountModel>
        let changes: CloudBackupDiff
        
        static func createFromLocalWallets(_ wallets: Set<MetaAccountModel>) -> Self {
            let changes = wallets.map { wallet in
                CloudBackupChange.delete(local: wallet)
            }
            
            return .init(localWallets: wallets, changes: changes)
        }
    }
    
    case noUpdates
    case updateLocal(State)
    case updateRemote(State)
}

protocol CloudBackupUpdateCalculationFactoryProtocol {
    func createUpdateCalculation(for fileUrl: URL) -> CompoundOperationWrapper<CloudBackupSyncResult>
}

enum CloudBackupUpdateCalculationError {
    case missingOrInvalidPassword
}

final class CloudBackupUpdateCalculationFactory {
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let backupOperationFactory: CloudBackupOperationFactoryProtocol
    let decodingManager: CloudBackupCoding
    let cryptoManager: CloudBackupCryptoManagerProtocol
    let diffManager: CloudBackupDiffCalculating
    
    init(
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        backupOperationFactory: CloudBackupOperationFactoryProtocol,
        decodingManager: CloudBackupCoding,
        cryptoManager: CloudBackupCryptoManagerProtocol,
        diffManager: CloudBackupDiffCalculating
    ) {
        self.syncMetadataManager = syncMetadataManager
        self.walletsRepository = walletsRepository
        self.backupOperationFactory = backupOperationFactory
        self.decodingManager = decodingManager
        self.cryptoManager = cryptoManager
        self.diffManager = diffManager
    }
}

extension CloudBackupUpdateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol {
    func createUpdateCalculation(for fileUrl: URL) -> CompoundOperationWrapper<CloudBackupSyncResult> {
        let walletsOperation = walletsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let remoteFileOperation = backupOperationFactory.createReadingOperation(for: fileUrl)
        
        let decodingOperation = ClosureOperation<CloudBackup.PublicData?> {
            let data = try remoteFileOperation.extractNoCancellableResultData()
            
            let optEncryptedModel = try data.map { try self.decodingManager.decode(data: $0) }
            
            guard let encryptedModel = optEncryptedModel else {
                return nil
            }
            
            guard let password = try syncMetadataManager.getPassword() else {
                throw CloudBackupUpdateCalculationError.missingOrInvalidPassword
            }
            
            let privateData = try Data(hexString: encryptedModel.privateData)
            _ = try cryptoManager.decrypt(data: privateData, password: password)
            
            return encryptedModel.publicData
        }
        
        decodingOperation.addDependency(remoteFileOperation)
        
        let diffOperation = ClosureOperation<CloudBackupDiff> {
            let wallets = try walletsOperation.extractNoCancellableResultData()
            
            guard let publicData = try decodingOperation.extractNoCancellableResultData() else {
                let state = CloudBackupSyncResult.State.createFromLocalWallets(wallets)
                return .updateRemote(state)
            }
            
            let diff = diffManager.calculateBetween(
                wallets: Set(wallets),
                publicBackupInfo: publicData
            )
            
            guard !diff.isEmpty else {
                return .noUpdates
            }
            
            let state = CloudBackupSyncResult.State(localWallets: wallets, changes: diff)
            
            guard let lastSyncTime = syncMetadataManager.getLastSyncDate() else {
                return .updateRemote(state)
            }
            
            if lastSyncTime < publicData.modificationDate {
                return .updateLocal(state)
            } else {
                return .updateRemote(state)
            }
        }
        
        diffOperation.addDependency(decodingOperation)
        
        return CompoundOperationWrapper(
            targetOperation: diffOperation,
            dependencies: [walletsOperation, remoteFileOperation, decodingOperation]
        )
    }
}
