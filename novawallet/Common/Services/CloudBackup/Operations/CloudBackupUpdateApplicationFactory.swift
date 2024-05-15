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
    let operationQueue: OperationQueue

    init(
        serviceFactory: CloudBackupServiceFactoryProtocol,
        walletRepositoryFactory: AccountRepositoryFactoryProtocol,
        walletsUpdater: WalletUpdateMediating,
        keystore: KeystoreProtocol,
        syncMetadata: CloudBackupSyncMetadataManaging,
        operationQueue: OperationQueue
    ) {
        self.serviceFactory = serviceFactory
        self.walletRepositoryFactory = walletRepositoryFactory
        self.walletsUpdater = walletsUpdater
        self.keystore = keystore
        self.syncMetadata = syncMetadata
        self.operationQueue = operationQueue
    }

    private func createRemoteExportOperation(
        dependingOn walletsOperation: BaseOperation<[MetaAccountModel]>,
        syncMetadata: CloudBackupSyncMetadataManaging
    ) -> BaseOperation<CloudBackup.EncryptedFileModel> {
        let exporter = serviceFactory.createSecretsExporter(from: keystore)

        return ClosureOperation {
            let wallets = try walletsOperation.extractNoCancellableResultData()

            guard let password = try syncMetadata.getPassword() else {
                throw CloudBackupUpdateApplicationFactoryError.missingPassword
            }

            let syncedTime = UInt64(Date().timeIntervalSince1970)

            return try exporter.backup(
                wallets: Set(wallets),
                password: password,
                modifiedAt: syncedTime
            )
        }
    }

    private func createRemoteSecretsImportOperation(
        from remoteModel: CloudBackup.EncryptedFileModel,
        changes: CloudBackupDiff,
        syncMetadata: CloudBackupSyncMetadataManaging,
    ) -> BaseOperation<Void> {
        let secretsImporter = serviceFactory.createSecretsImporter(to: keystore)

        return ClosureOperation<Void> {
            let walletIdsToUpdateSecrets = changes.compactMap { change in
                switch change {
                case let .new(remote):
                    return remote.metaId
                case let .updatedChainAccounts(_, remote, _):
                    return remote.metaId
                case .delete, .updatedMetadata:
                    return nil
                }
            }

            guard !walletIdsToUpdateSecrets.isEmpty else {
                return
            }

            guard let password = try syncMetadata.getPassword() else {
                throw CloudBackupUpdateApplicationFactoryError.missingPassword
            }

            _ = try secretsImporter.importBackup(
                from: remoteModel,
                password: password,
                onlyWallets: Set(walletIdsToUpdateSecrets)
            )
        }
    }

    private func localChangesDeriveOperation(
        from changes: CloudBackupDiff,
        dependingOn walletsOperation: BaseOperation<[ManagedMetaAccountModel]>
    ) -> BaseOperation<SyncChanges<ManagedMetaAccountModel>> {
        ClosureOperation {
            let localWallets = try walletsOperation.extractNoCancellableResultData()
            let maxOrder = localWallets.max(by: { $0.order < $1.order })?.order
            let walletsById = localWallets.reduceToDict()

            var newOrUpdatedWallets: [ManagedMetaAccountModel] = []
            var removedWallets: [ManagedMetaAccountModel] = []

            var nextOrder = maxOrder.map { $0 + 1 } ?? 0

            for change in changes {
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
                case let .updatedChainAccounts(_, remote, _):
                    if let local = walletsById[remote.metaId] {
                        newOrUpdatedWallets.append(
                            ManagedMetaAccountModel(
                                info: remote,
                                isSelected: local.isSelected,
                                order: local.order
                            )
                        )
                    }
                case let .updatedMetadata(_, remote):
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
    }

    private func createUpdateLocalWrapper(
        for state: CloudBackupSyncResult.UpdateLocal
    ) -> CompoundOperationWrapper<Void> {
        let walletsOperation = walletRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        ).fetchAllOperation(with: RepositoryFetchOptions())
        
        let secretsImportOperation = createRemoteSecretsImportOperation(
            from: state.remoteModel,
            changes: state.changes,
            syncMetadata: syncMetadata
        )

        let changesOperation = localChangesDeriveOperation(
            from: state.changes,
            dependingOn: walletsOperation
        )
        
        changesOperation.addDependency(walletsOperation)

        let updateWrapper = walletsUpdater.saveChanges {
            // make sure secrets imported correctly before saving wallets
            try secretsImportOperation.extractNoCancellableResultData()
            return try changesOperation.extractNoCancellableResultData()
        }

        updateWrapper.addDependency(operations: [secretsImportOperation, changesOperation])

        let mappingOperation = ClosureOperation {
            _ = try updateWrapper.targetOperation.extractNoCancellableResultData()
        }
        
        mappingOperation.addDependency(updateWrapper.targetOperation)
        
        return updateWrapper
            .insertingTail(operation: mappingOperation)
            .insertingHead(
                operations: [walletsOperation, secretsImportOperation, changesOperation]
            )
    }

    private func createUpdateRemoteWrapper() -> CompoundOperationWrapper<Void> {
        guard let remoteUrl = serviceFactory.createFileManager().getFileUrl() else {
            return CompoundOperationWrapper.createWithError(
                CloudBackupUpdateApplicationFactoryError.cloudUnavailable
            )
        }

        let walletsRepository = walletRepositoryFactory.createMetaAccountRepository(
            for: NSPredicate.cloudSyncableWallets,
            sortDescriptors: []
        )

        let allWalletsOperation = walletsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let exportOperation = createRemoteExportOperation(
            dependingOn: allWalletsOperation,
            syncMetadata: syncMetadata
        )

        exportOperation.addDependency(allWalletsOperation)

        let coder = serviceFactory.createCodingManager()
        let encodingOperation = ClosureOperation<Data> {
            let remoteModel = try exportOperation.extractNoCancellableResultData()
            return try coder.encode(backup: remoteModel)
        }

        encodingOperation.addDependency(exportOperation)

        let uploadWrapper = serviceFactory.createUploadFactory().createUploadWrapper(
            for: remoteUrl,
            timeoutInterval: CloudBackup.backupSaveTimeout
        ) {
            try encodingOperation.extractNoCancellableResultData()
        }

        uploadWrapper.addDependency(operations: [encodingOperation])

        return uploadWrapper.insertingHead(
                operations: [allWalletsOperation, exportOperation, encodingOperation]
            )
    }

    private func createLocalRemoteUnionWrapper(
        for state: CloudBackupSyncResult.State
    ) -> CompoundOperationWrapper<Void> {
        let newChanges = state.changes.filter { change in
            switch change {
            case .new:
                return true
            case .delete, .updatedMetadata, .updatedChainAccounts:
                return false
            }
        }

        let newState = CloudBackupSyncResult.State(
            localWallets: state.localWallets,
            changes: newChanges
        )

        let localUpdateWrapper = createUpdateLocalWrapper(for: newState)

        let remoteUpdateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            _ = try localUpdateWrapper.targetOperation.extractNoCancellableResultData()

            return self.createUpdateRemoteWrapper()
        }

        remoteUpdateWrapper.addDependency(wrapper: localUpdateWrapper)

        return remoteUpdateWrapper.insertingHead(operations: localUpdateWrapper.allOperations)
    }
}
