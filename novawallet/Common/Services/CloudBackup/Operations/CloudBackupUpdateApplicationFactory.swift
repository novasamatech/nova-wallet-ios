import Foundation
import RobinHood
import SoraKeystore

protocol CloudBackupUpdateApplicationFactoryProtocol {
    func createUpdateApplyOperation(for changes: CloudBackupSyncResult.Changes) -> CompoundOperationWrapper<Void>
}

enum CloudBackupUpdateApplicationFactoryError: Error {
    case cloudUnavailable
    case noRemoteFile
    case missingPassword
}

final class CloudBackupUpdateApplicationFactory {
    let serviceFactory: CloudBackupServiceFactoryProtocol
    let walletRepositoryFactory: AccountRepositoryFactoryProtocol
    let walletsUpdater: WalletUpdateMediating
    let keystore: KeystoreProtocol
    let syncMetadata: CloudBackupSyncMetadataManaging

    init(
        serviceFactory: CloudBackupServiceFactoryProtocol,
        walletRepositoryFactory: AccountRepositoryFactoryProtocol,
        walletsUpdater: WalletUpdateMediating,
        keystore: KeystoreProtocol,
        syncMetadata: CloudBackupSyncMetadataManaging
    ) {
        self.serviceFactory = serviceFactory
        self.walletRepositoryFactory = walletRepositoryFactory
        self.keystore = keystore
        self.syncMetadata = syncMetadata
    }
    
    private func createReadWrapper() -> CompoundOperationWrapper<CloudBackup.EncryptedFileModel> {
        let fileManager = serviceFactory.createFileManager()
        
        guard let remoteFileUrl = fileManager.getFileUrl() else {
            return CompoundOperationWrapper.createWithError(
                CloudBackupUpdateApplicationFactoryError.cloudUnavailable
            )
        }
        
        let operationFactory = serviceFactory.createOperationFactory()
        let readOperation = operationFactory.createReadingOperation(for: remoteFileUrl)
        
        let decoder = serviceFactory.createCodingManager()
        
        let decoderOperation = ClosureOperation<CloudBackup.EncryptedFileModel> {
            guard let data = readOperation.extractNoCancellableResultData() else {
                throw CloudBackupUpdateApplicationFactoryError.noRemoteFile
            }
            
            return decoder.decode(data: data)
        }
        
        decoderOperation.addDependency(readOperation)
        
        return CompoundOperationWrapper(targetOperation: decoderOperation, dependencies: [readOperation])
    }
    
    private func createRemoteSecretsImportOperation(
        for state: CloudBackupSyncResult.State,
        syncMetadata: CloudBackupSyncMetadataManaging,
        dependingOn readOperation: BaseOperation<CloudBackup.EncryptedFileModel>
    ) -> BaseOperation<Void> {
        let secretsImporter = serviceFactory.createSecretsImporter(to: keystore)
        
        return ClosureOperation<Void> {
            let model = try readOperation.extractNoCancellableResultData()
            
            let walletIdsToUpdateSecrets = state.changes.compactMap { change in
                switch change {
                case let .new(remote):
                    return remote.metaId
                case .updatedChainAccounts(_, let remote, _):
                    return remote.metaId
                case .delete, .updatedMetadata:
                    return nil
                }
            }
            
            guard !walletIdsToUpdateSecrets.isEmpty else {
                return
            }
            
            guard let password = syncMetadata.getPassword() else {
                throw CloudBackupUpdateApplicationFactoryError.missingPassword
            }
            
            try secretsImporter.importBackup(
                from: model,
                password: password,
                onlyWallets: walletIdsToUpdateSecrets
            )
        }
    }
    
    private func createUpdateLocalWrapper(
        for state: CloudBackupSyncResult.State
    ) -> CompoundOperationWrapper<Void> {
        let readWrapper = createReadWrapper()
        let secretsImportOperation = createRemoteSecretsImportOperation(
            for: state,
            syncMetadata: syncMetadata,
            dependingOn: readWrapper.targetOperation
        )
        
        secretsImportOperation.addDependency(readWrapper.targetOperation)
        
        let changesOperation = ClosureOperation {
            _ = secretsImportOperation.extractNoCancellableResultData()
            
            let maxOrder = state.localWallets.max(by: { $0.order < $1.order })
            let walletsById = Array(state.localWallets).reduceToDict()
            
            var newOrUpdatedWallets: [ManagedMetaAccountModel] = []
            var removedWallets: [ManagedMetaAccountModel] = []
            
            var nextOrder = maxOrder.map { $0 + 1} ?? 0
            
            for change in state.changes {
                switch change {
                case let .new(remote):
                    newOrUpdatedWallets.append(
                        ManagedMetaAccountModel(
                            info: remote,
                            isSelected: false,
                            order: nextOrder
                        )
                    )
                    
                    nextOrder += 1
                case .updatedChainAccounts(_, let remote, _):
                    if let local = walletsById[remote.metaId] {
                        newOrUpdatedWallets.append(
                            ManagedMetaAccountModel(
                                info: remote,
                                isSelected: local.isSelected,
                                order: local.order
                            )
                        )
                    }
                case .updatedMetadata(_, let remote):
                    if let local = walletsById[remote.metaId] {
                        newOrUpdatedWallets.append(
                            ManagedMetaAccountModel(
                                info: remote,
                                isSelected: local.isSelected,
                                order: local.order
                            )
                        )
                    }
                case let .delete(local):
                    if let managed = walletsById[local.metaId] {
                        removedWallets.append(managed)
                    }
                }
            }
            
            return SyncChanges(newOrUpdatedItems: newOrUpdatedWallets, removedItems: removedWallets)
        }
        
        let updateOperation = walletsUpdater.saveChanges({ try changesOperation.extractNoCancellableResultData() })
    }
}
