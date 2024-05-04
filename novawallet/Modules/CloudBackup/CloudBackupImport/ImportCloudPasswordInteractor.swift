import UIKit
import RobinHood
import SoraKeystore

final class ImportCloudPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?

    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let selectedWalletSettings: SelectedWalletSettings
    let keystore: KeystoreProtocol

    init(
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        selectedWalletSettings: SelectedWalletSettings,
        keystore: KeystoreProtocol
    ) {
        self.cloudBackupFacade = cloudBackupFacade
        self.walletRepository = walletRepository
        self.selectedWalletSettings = selectedWalletSettings
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

    private func setupSelectedWallet() {
        selectedWalletSettings.setup(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(optWallet):
                guard optWallet != nil else {
                    self?.presenter?.didReceive(error: .selectedWallet(nil))
                    return
                }

                self?.presenter?.didImportBackup()
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
                    self?.setupSelectedWallet()
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
