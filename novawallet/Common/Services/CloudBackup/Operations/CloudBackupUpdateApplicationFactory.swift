import Foundation
import Operation_iOS
import Keystore_iOS

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
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let operationQueue: OperationQueue

    init(
        serviceFactory: CloudBackupServiceFactoryProtocol,
        walletRepositoryFactory: AccountRepositoryFactoryProtocol,
        walletsUpdater: WalletUpdateMediating,
        keystore: KeystoreProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        operationQueue: OperationQueue
    ) {
        self.serviceFactory = serviceFactory
        self.walletRepositoryFactory = walletRepositoryFactory
        self.walletsUpdater = walletsUpdater
        self.keystore = keystore
        self.syncMetadataManager = syncMetadataManager
        self.operationQueue = operationQueue
    }

    private func addingSyncTimeSaveOperation(
        to updateWrapper: CompoundOperationWrapper<Void>,
        syncTime: UInt64,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) -> CompoundOperationWrapper<Void> {
        let saveTimeOperation = ClosureOperation {
            _ = try updateWrapper.targetOperation.extractNoCancellableResultData()
            syncMetadataManager.saveLastSyncTimestamp(syncTime)
        }

        saveTimeOperation.addDependency(updateWrapper.targetOperation)

        return updateWrapper.insertingTail(operation: saveTimeOperation)
    }

    private func createRemoteExportOperation(
        for wallets: Set<MetaAccountModel>,
        syncTime: UInt64,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) -> BaseOperation<CloudBackup.EncryptedFileModel> {
        let exporter = serviceFactory.createSecretsExporter(from: keystore)

        return ClosureOperation {
            guard let password = try syncMetadataManager.getPassword() else {
                throw CloudBackupUpdateApplicationFactoryError.missingPassword
            }

            return try exporter.backup(wallets: wallets, password: password, modifiedAt: syncTime)
        }
    }

    private func createRemoteSecretsImportOperation(
        from remoteModel: CloudBackup.EncryptedFileModel,
        changes: CloudBackupDiff,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) -> BaseOperation<Void> {
        let secretsImporter = serviceFactory.createSecretsImporter(to: keystore)

        return ClosureOperation<Void> {
            let walletIdsToUpdateSecrets = changes.compactMap { change in
                switch change {
                case let .new(remote):
                    return remote.metaId
                case let .updatedChainAccounts(_, remote, _):
                    return remote.metaId
                case let .updatedMainAccounts(_, remote):
                    return remote.metaId
                case .delete, .updatedMetadata:
                    return nil
                }
            }

            guard !walletIdsToUpdateSecrets.isEmpty else {
                return
            }

            guard let password = try syncMetadataManager.getPassword() else {
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
                case let .updatedMainAccounts(_, remote):
                    if let local = walletsById[remote.metaId] {
                        newOrUpdatedWallets.append(
                            ManagedMetaAccountModel(
                                info: remote,
                                isSelected: local.isSelected,
                                order: local.order
                            )
                        )
                    }
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
        from remoteModel: CloudBackup.EncryptedFileModel,
        changes: CloudBackupDiff
    ) -> CompoundOperationWrapper<WalletUpdateMediatingResult> {
        let walletsOperation = walletRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        ).fetchAllOperation(with: RepositoryFetchOptions())

        let secretsImportOperation = createRemoteSecretsImportOperation(
            from: remoteModel,
            changes: changes,
            syncMetadataManager: syncMetadataManager
        )

        let changesOperation = localChangesDeriveOperation(
            from: changes,
            dependingOn: walletsOperation
        )

        changesOperation.addDependency(walletsOperation)

        let updateWrapper = walletsUpdater.saveChanges {
            // make sure secrets imported correctly before saving wallets
            try secretsImportOperation.extractNoCancellableResultData()
            return try changesOperation.extractNoCancellableResultData()
        }

        updateWrapper.addDependency(operations: [secretsImportOperation, changesOperation])

        return updateWrapper
            .insertingHead(
                operations: [walletsOperation, secretsImportOperation, changesOperation]
            )
    }

    private func createUpdateLocalWrapper(
        for state: CloudBackupSyncResult.UpdateLocal
    ) -> CompoundOperationWrapper<Void> {
        let updateWrapper = createUpdateLocalWrapper(from: state.remoteModel, changes: state.changes)

        let mappingOperation = ClosureOperation {
            _ = try updateWrapper.targetOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(updateWrapper.targetOperation)

        return addingSyncTimeSaveOperation(
            to: updateWrapper.insertingTail(operation: mappingOperation),
            syncTime: state.syncTime,
            syncMetadataManager: syncMetadataManager
        )
    }

    private func createUpdateRemoteWrapper(
        from wallets: Set<MetaAccountModel>,
        syncTime: UInt64
    ) -> CompoundOperationWrapper<Void> {
        let fileManager = serviceFactory.createFileManager()

        guard
            let remoteUrl = fileManager.getFileUrl() else {
            return CompoundOperationWrapper.createWithError(
                CloudBackupUpdateApplicationFactoryError.cloudUnavailable
            )
        }

        let exportOperation = createRemoteExportOperation(
            for: wallets,
            syncTime: syncTime,
            syncMetadataManager: syncMetadataManager
        )

        let coder = serviceFactory.createCodingManager()
        let encodingOperation = ClosureOperation<Data> {
            let remoteModel = try exportOperation.extractNoCancellableResultData()
            return try coder.encode(backup: remoteModel)
        }

        encodingOperation.addDependency(exportOperation)

        let writeOperation = serviceFactory.createOperationFactory().createWritingOperation(
            for: remoteUrl
        ) {
            try encodingOperation.extractNoCancellableResultData()
        }

        writeOperation.addDependency(encodingOperation)

        return CompoundOperationWrapper(
            targetOperation: writeOperation,
            dependencies: [exportOperation, encodingOperation]
        )
    }

    private func createUpdateRemoteWrapper(
        for state: CloudBackupSyncResult.UpdateRemote
    ) -> CompoundOperationWrapper<Void> {
        let updateWrapper = createUpdateRemoteWrapper(
            from: Set(state.localWallets.map(\.info)),
            syncTime: state.syncTime
        )

        return addingSyncTimeSaveOperation(
            to: updateWrapper,
            syncTime: state.syncTime,
            syncMetadataManager: syncMetadataManager
        )
    }

    private func createLocalRemoteUnionWrapper(
        for state: CloudBackupSyncResult.UpdateByUnion
    ) -> CompoundOperationWrapper<Void> {
        let localUpdateWrapper = createUpdateLocalWrapper(
            from: state.remoteModel,
            changes: Set(state.addingWallets.map { .new(remote: $0) })
        )

        let remoteUpdateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            _ = try localUpdateWrapper.targetOperation.extractNoCancellableResultData()
            let exportWallets = Set(state.localWallets.map(\.info)).union(state.addingWallets)

            return self.createUpdateRemoteWrapper(from: exportWallets, syncTime: state.syncTime)
        }

        remoteUpdateWrapper.addDependency(wrapper: localUpdateWrapper)

        let wrapper = remoteUpdateWrapper.insertingHead(operations: localUpdateWrapper.allOperations)

        return addingSyncTimeSaveOperation(
            to: wrapper,
            syncTime: state.syncTime,
            syncMetadataManager: syncMetadataManager
        )
    }
}

extension CloudBackupUpdateApplicationFactory: CloudBackupUpdateApplicationFactoryProtocol {
    func createUpdateApplyOperation(
        for changes: CloudBackupSyncResult.Changes
    ) -> CompoundOperationWrapper<Void> {
        switch changes {
        case let .updateLocal(updateLocal):
            return createUpdateLocalWrapper(for: updateLocal)
        case let .updateRemote(updateRemote):
            return createUpdateRemoteWrapper(for: updateRemote)
        case let .updateByUnion(updateByUnion):
            return createLocalRemoteUnionWrapper(for: updateByUnion)
        }
    }
}
