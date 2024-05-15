import Foundation
import RobinHood
import SoraKeystore
import IrohaCrypto

enum CloudBackupSyncResult: Equatable {
    struct UpdateLocal: Equatable {
        let localWallets: Set<ManagedMetaAccountModel>
        let remoteModel: CloudBackup.EncryptedFileModel
        let changes: CloudBackupDiff
        let syncTime: UInt64
    }
    
    struct UpdateRemote {
        let localWallets: Set<ManagedMetaAccountModel>
        let syncTime: UInt64
    }
    
    struct UpdateByUnion {
        let localWallets: Set<ManagedMetaAccountModel>
        let remoteModel: CloudBackup.EncryptedFileModel
        let addingWallets: Set<MetaAccountModel>
        let syncTime: UInt64
    }

    enum Changes: Equatable {
        case updateLocal(UpdateLocal)
        case updateRemote(UpdateRemote)
        case updateByUnion(UpdateByUnion)
    }

    enum Issue: Equatable {
        case missingOrInvalidPassword
        case remoteReadingFailed
        case remoteDecodingFailed
        case internalFailure
    }

    case noUpdates
    case changes(Changes)
    case issue(Issue)
}

protocol CloudBackupUpdateCalculationFactoryProtocol {
    func createUpdateCalculation(for fileUrl: URL) -> CompoundOperationWrapper<CloudBackupSyncResult>
}

enum CloudBackupUpdateCalculationError: Error {
    case missingOrInvalidPassword
    case invalidPublicData
}

final class CloudBackupUpdateCalculationFactory {
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let walletsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let backupOperationFactory: CloudBackupOperationFactoryProtocol
    let decodingManager: CloudBackupCoding
    let cryptoManager: CloudBackupCryptoManagerProtocol
    let diffManager: CloudBackupDiffCalculating

    init(
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        walletsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
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

    private func createDiffOperation(
        dependingOn walletsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        decodingOperation: BaseOperation<CloudBackup.EncryptedFileModel?>
    ) -> ClosureOperation<CloudBackupSyncResult> {
        ClosureOperation<CloudBackupSyncResult> {
            do {
                let wallets = try walletsOperation.extractNoCancellableResultData()

                let syncTime = UInt64(Date().timeIntervalSince1970)
                
                guard let remoteModel = try decodingOperation.extractNoCancellableResultData() else {
                    let state = CloudBackupSyncResult.UpdateRemote(
                        localWallets: Set(wallets.map(\.info)),
                        syncTime: syncTime
                    )
                    
                    return .changes(.updateRemote(state))
                }

                let diff = try self.diffManager.calculateBetween(
                    wallets: Set(wallets.map(\.info)),
                    publicBackupInfo: remoteModel.publicData
                )

                guard !diff.isEmpty else {
                    return .noUpdates
                }

                guard let lastSyncTime = self.syncMetadataManager.getLastSyncDate() else {
                    let state = CloudBackupSyncResult.UpdateByUnion(
                        localWallets: Set(wallets),
                        remoteModel: remoteModel,
                        addingWallets: diff.getNewWallets(),
                        syncTime: syncTime
                    )
                    
                    return .changes(.updateByUnion(state))
                }

                if lastSyncTime < remoteModel.publicData.modifiedAt {
                    let state = CloudBackupSyncResult.UpdateLocal(
                        localWallets: Set(wallets),
                        remoteModel: remoteModel,
                        changes: diff,
                        syncTime: syncTime
                    )
                    
                    return .changes(.updateLocal(state))
                } else {
                    let state = CloudBackupSyncResult.UpdateRemote(localWallets: Set(wallets), syncTime: syncTime)
                    return .changes(.updateRemote(state))
                }
            } catch CloudBackupUpdateCalculationError.missingOrInvalidPassword {
                return .issue(.missingOrInvalidPassword)
            } catch CloudBackupUpdateCalculationError.invalidPublicData {
                return .issue(.remoteDecodingFailed)
            } catch CloudBackupOperationFactoryError.readingFailed {
                return .issue(.remoteReadingFailed)
            } catch {
                return .issue(.internalFailure)
            }
        }
    }
}

extension CloudBackupUpdateCalculationFactory: CloudBackupUpdateCalculationFactoryProtocol {
    func createUpdateCalculation(for fileUrl: URL) -> CompoundOperationWrapper<CloudBackupSyncResult> {
        let walletsOperation = walletsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let remoteFileOperation = backupOperationFactory.createReadingOperation(for: fileUrl)

        let decodingOperation = ClosureOperation<CloudBackup.EncryptedFileModel?> {
            guard let data = try remoteFileOperation.extractNoCancellableResultData() else {
                return nil
            }

            guard let encryptedModel = try? self.decodingManager.decode(data: data) else {
                throw CloudBackupUpdateCalculationError.invalidPublicData
            }

            guard let password = try self.syncMetadataManager.getPassword() else {
                throw CloudBackupUpdateCalculationError.missingOrInvalidPassword
            }

            let privateData = try Data(hexString: encryptedModel.privateData)
            let optDecryption = try? self.cryptoManager.decrypt(data: privateData, password: password)

            if optDecryption == nil {
                throw CloudBackupUpdateCalculationError.missingOrInvalidPassword
            }

            return encryptedModel
        }

        decodingOperation.addDependency(remoteFileOperation)

        let diffOperation = createDiffOperation(
            dependingOn: walletsOperation,
            decodingOperation: decodingOperation
        )

        diffOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: diffOperation,
            dependencies: [walletsOperation, remoteFileOperation, decodingOperation]
        )
    }
}
