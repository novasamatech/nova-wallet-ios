import Foundation
import RobinHood
import SoraKeystore
import IrohaCrypto

enum CloudBackupSyncResult: Equatable {
    struct State: Equatable {
        let localWallets: Set<ManagedMetaAccountModel>
        let changes: CloudBackupDiff

        static func createFromLocalWallets(_ wallets: Set<ManagedMetaAccountModel>) -> Self {
            let changes = wallets.map { wallet in
                CloudBackupChange.delete(local: wallet.info)
            }

            return .init(localWallets: wallets, changes: Set(changes))
        }
    }

    enum Changes: Equatable {
        case updateLocal(State)
        case updateRemote
        case unionLocalAndRemote(State)
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
        decodingOperation: BaseOperation<CloudBackup.PublicData?>
    ) -> ClosureOperation<CloudBackupSyncResult> {
        ClosureOperation<CloudBackupSyncResult> {
            do {
                let wallets = try walletsOperation.extractNoCancellableResultData()

                guard let publicData = try decodingOperation.extractNoCancellableResultData() else {
                    return .changes(.updateRemote)
                }

                let diff = try self.diffManager.calculateBetween(
                    wallets: Set(wallets.map(\.info)),
                    publicBackupInfo: publicData
                )

                guard !diff.isEmpty else {
                    return .noUpdates
                }

                let state = CloudBackupSyncResult.State(localWallets: Set(wallets), changes: diff)

                guard let lastSyncTime = self.syncMetadataManager.getLastSyncDate() else {
                    return .changes(.unionLocalAndRemote(state))
                }

                if lastSyncTime < publicData.modifiedAt {
                    return .changes(.updateLocal(state))
                } else {
                    return .changes(.updateRemote)
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

        let decodingOperation = ClosureOperation<CloudBackup.PublicData?> {
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

            return encryptedModel.publicData
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
