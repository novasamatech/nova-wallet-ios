import Foundation
import Keystore_iOS
import Operation_iOS

final class CloudBackupEnablePasswordInteractor {
    weak var presenter: CloudBackupCreateInteractorOutputProtocol?

    let repositoryFactory: AccountRepositoryFactoryProtocol
    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let keystore: KeystoreProtocol
    let operationQueue: OperationQueue

    private var isCreatingBackup: Bool = false

    init(
        repositoryFactory: AccountRepositoryFactoryProtocol,
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.repositoryFactory = repositoryFactory
        self.cloudBackupFacade = cloudBackupFacade
        self.syncMetadataManager = syncMetadataManager
        self.keystore = keystore
        self.operationQueue = operationQueue
    }

    private func completeSuccessfully(with password: String) {
        // we already saved the wallet better to ask a user to resolve the password in settings
        try? syncMetadataManager.enableBackup(for: password)

        isCreatingBackup = false
        presenter?.didCreateWallet()
    }

    private func completeWithError(_ error: CloudBackupCreateInteractorError) {
        isCreatingBackup = false
        presenter?.didReceive(error: error)
    }

    private func backup(wallets: Set<MetaAccountModel>, password: String) {
        cloudBackupFacade.createBackup(
            wallets: wallets,
            keystore: keystore,
            password: password,
            runCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.completeSuccessfully(with: password)
            case let .failure(error):
                self?.completeWithError(.backup(error))
            }
        }
    }
}

extension CloudBackupEnablePasswordInteractor: CloudBackupCreateInteractorInputProtocol {
    func createWallet(for password: String) {
        guard !isCreatingBackup else {
            presenter?.didReceive(error: .alreadyInProgress)
            return
        }

        isCreatingBackup = true

        let repository = repositoryFactory.createManagedMetaAccountRepository(
            for: NSPredicate.cloudSyncableWallets,
            sortDescriptors: []
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(managedWallets):
                let wallets = Set(managedWallets.map(\.info))

                guard !wallets.isEmpty else {
                    self?.completeWithError(.walletCreation(CommonError.dataCorruption))
                    return
                }

                self?.backup(wallets: wallets, password: password)
            case let .failure(error):
                self?.completeWithError(.walletCreation(error))
            }
        }
    }
}
