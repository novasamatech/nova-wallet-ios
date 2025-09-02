import UIKit
import Operation_iOS
import Keystore_iOS

final class ImportCloudPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?

    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let selectedWalletSettings: SelectedWalletSettings
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let keystore: KeystoreProtocol

    init(
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        selectedWalletSettings: SelectedWalletSettings,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        keystore: KeystoreProtocol
    ) {
        self.cloudBackupFacade = cloudBackupFacade
        self.walletRepository = walletRepository
        self.selectedWalletSettings = selectedWalletSettings
        self.syncMetadataManager = syncMetadataManager
        self.keystore = keystore
    }

    private func handleImport(error: CloudBackupServiceFacadeError) {
        switch error {
        case let .backupDecoding(error):
            presenter?.didReceive(error: .backupBroken(error))
        case .invalidBackupPassword:
            presenter?.didReceive(error: .invalidPassword)
        default:
            presenter?.didReceive(error: .importInternal(error))
        }
    }

    private func enableBackupAndComplete(for password: String) {
        // we already saved the wallet better to ask a user to resolve the password in settings
        try? syncMetadataManager.enableBackup(for: password)

        presenter?.didImportBackup(with: password)
    }

    private func setupSelectedWallet(for password: String) {
        selectedWalletSettings.setup(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(optWallet):
                guard optWallet != nil else {
                    self?.presenter?.didReceive(error: .selectedWallet(nil))
                    return
                }

                self?.enableBackupAndComplete(for: password)
            case let .failure(error):
                self?.presenter?.didReceive(error: .selectedWallet(error))
            }
        }
    }
}

extension ImportCloudPasswordInteractor: ImportCloudPasswordInteractorInputProtocol {
    func importBackup(for password: String) {
        cloudBackupFacade.importBackup(
            to: walletRepository,
            keystore: keystore,
            password: password,
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(wallets):
                if !wallets.isEmpty {
                    self?.setupSelectedWallet(for: password)
                } else {
                    self?.presenter?.didReceive(error: .emptyBackup)
                }
            case let .failure(error):
                self?.handleImport(error: error)
            }
        }
    }

    func deleteBackup() {
        cloudBackupFacade.deleteBackup(
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didDeleteBackup()
            case let .failure(error):
                self?.presenter?.didReceive(error: .deleteFailed(error))
            }
        }
    }
}
