import UIKit
import Keystore_iOS
import NovaCrypto
import Operation_iOS

final class CloudBackupCreateInteractor {
    weak var presenter: CloudBackupCreateInteractorOutputProtocol?

    let walletName: String
    let walletRequestFactory: WalletCreationRequestFactoryProtocol
    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let syncMetadataManager: CloudBackupSyncMetadataManaging
    let walletSettings: SelectedWalletSettings
    let persistentKeystore: KeystoreProtocol
    let operationQueue: OperationQueue

    private var isCreatingWallet: Bool = false

    init(
        walletName: String,
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        walletRequestFactory: WalletCreationRequestFactoryProtocol,
        walletSettings: SelectedWalletSettings,
        persistentKeystore: KeystoreProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging,
        operationQueue: OperationQueue
    ) {
        self.walletName = walletName
        self.cloudBackupFacade = cloudBackupFacade
        self.walletSettings = walletSettings
        self.walletRequestFactory = walletRequestFactory
        self.persistentKeystore = persistentKeystore
        self.syncMetadataManager = syncMetadataManager
        self.operationQueue = operationQueue
    }

    private func enableBackupAndComplete(for password: String) {
        // we already saved the wallet better to ask a user to resolve the password in settings
        try? syncMetadataManager.enableBackup(for: password)

        didComplete(with: .success(()))
    }

    private func backup(
        wallet: MetaAccountModel,
        password: String,
        proxyKeystore: KeychainProxyProtocol
    ) {
        cloudBackupFacade.createBackup(
            wallets: [wallet],
            keystore: proxyKeystore,
            password: password,
            runCompletionIn: .main
        ) { result in
            switch result {
            case .success:
                self.saveWallet(
                    wallet,
                    proxyKeystore: proxyKeystore,
                    persistentKeystore: self.persistentKeystore,
                    password: password
                )
            case let .failure(error):
                self.didComplete(with: .failure(.backup(error)))
            }
        }
    }

    private func saveWallet(
        _ wallet: MetaAccountModel,
        proxyKeystore: KeychainProxyProtocol,
        persistentKeystore: KeystoreProtocol,
        password: String
    ) {
        let saveOperation = ClosureOperation<Void> {
            try proxyKeystore.flushToActual(persistentStore: persistentKeystore)
            self.walletSettings.save(value: wallet)
        }

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case .success:
                self.enableBackupAndComplete(for: password)
            case let .failure(error):
                self.didComplete(with: .failure(.walletSave(error)))
            }
        }
    }

    private func didComplete(with result: Result<Void, CloudBackupCreateInteractorError>) {
        isCreatingWallet = false

        switch result {
        case .success:
            presenter?.didCreateWallet()
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

extension CloudBackupCreateInteractor: CloudBackupCreateInteractorInputProtocol {
    func createWallet(for password: String) {
        guard !isCreatingWallet else {
            presenter?.didReceive(error: .alreadyInProgress)
            return
        }

        isCreatingWallet = true

        do {
            let proxyKeystore = KeychainProxy()

            let request = try walletRequestFactory.createNewWalletRequest(for: walletName)

            let operation = MetaAccountOperationFactory(keystore: proxyKeystore).newSecretsMetaAccountOperation(
                request: request.walletRequest,
                mnemonic: request.mnemonic
            )

            execute(
                operation: operation,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                switch result {
                case let .success(wallet):
                    self.backup(wallet: wallet, password: password, proxyKeystore: proxyKeystore)
                case let .failure(error):
                    self.didComplete(with: .failure(.walletCreation(error)))
                }
            }
        } catch {
            didComplete(with: .failure(.mnemonicCreation(error)))
        }
    }
}
