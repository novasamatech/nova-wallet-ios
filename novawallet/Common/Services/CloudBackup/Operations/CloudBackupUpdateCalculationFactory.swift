import Foundation
import Operation_iOS
import Keystore_iOS
import NovaCrypto

enum CloudBackupSyncResult: Equatable {
    struct UpdateLocal: Equatable {
        let localWallets: Set<ManagedMetaAccountModel>
        let remoteModel: CloudBackup.EncryptedFileModel
        let changes: CloudBackupDiff
        let syncTime: UInt64
    }

    struct UpdateRemote: Equatable {
        let localWallets: Set<ManagedMetaAccountModel>
        let syncTime: UInt64
    }

    struct UpdateByUnion: Equatable {
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
        case missingPassword
        case invalidPassword
        case newBackupCreationNeeded
        case remoteReadingFailed
        case remoteDecodingFailed
        case remoteEmpty
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
    case missingPassword
    case invalidPassword
    case invalidPublicData
    case newBackupNeeded
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
                        localWallets: Set(wallets),
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

                guard let lastSyncTime = self.syncMetadataManager.getLastSyncTimestamp() else {
                    let state = CloudBackupSyncResult.UpdateByUnion(
                        localWallets: Set(wallets),
                        remoteModel: remoteModel,
                        addingWallets: diff.deriveNewWallets(),
                        syncTime: syncTime
                    )

                    return .changes(.updateByUnion(state))
                }

                if lastSyncTime < remoteModel.publicData.modifiedAt {
                    guard !remoteModel.publicData.wallets.isEmpty else {
                        return .issue(.remoteEmpty)
                    }

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
            } catch CloudBackupUpdateCalculationError.newBackupNeeded {
                return .issue(.newBackupCreationNeeded)
            } catch CloudBackupUpdateCalculationError.missingPassword {
                return .issue(.missingPassword)
            } catch CloudBackupUpdateCalculationError.invalidPassword {
                return .issue(.invalidPassword)
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
            let optPassword = try self.syncMetadataManager.getPassword()
            let optData = try remoteFileOperation.extractNoCancellableResultData()

            if optPassword == nil, optData == nil {
                throw CloudBackupUpdateCalculationError.newBackupNeeded
            }

            guard let data = optData else {
                return nil
            }

            guard let encryptedModel = try? self.decodingManager.decode(data: data) else {
                throw CloudBackupUpdateCalculationError.invalidPublicData
            }

            guard let password = optPassword else {
                throw CloudBackupUpdateCalculationError.missingPassword
            }

            let privateData = try Data(hexString: encryptedModel.privateData)
            let optDecryption = try? self.cryptoManager.decrypt(data: privateData, password: password)

            if optDecryption == nil {
                throw CloudBackupUpdateCalculationError.invalidPassword
            }

            return encryptedModel
        }

        decodingOperation.addDependency(remoteFileOperation)

        let diffOperation = createDiffOperation(
            dependingOn: walletsOperation,
            decodingOperation: decodingOperation
        )

        diffOperation.addDependency(decodingOperation)
        diffOperation.addDependency(walletsOperation)

        return CompoundOperationWrapper(
            targetOperation: diffOperation,
            dependencies: [walletsOperation, remoteFileOperation, decodingOperation]
        )
    }
}
