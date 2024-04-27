import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

final class CloudBackupCreateInteractor {
    weak var presenter: CloudBackupCreateInteractorOutputProtocol?

    let walletName: String
    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let walletSettings: SelectedWalletSettings
    let persistentKeystore: KeystoreProtocol
    let operationQueue: OperationQueue

    private var isCreatingWallet: Bool = false

    init(
        walletName: String,
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        walletSettings: SelectedWalletSettings,
        persistentKeystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.walletName = walletName
        self.cloudBackupFacade = cloudBackupFacade
        self.walletSettings = walletSettings
        self.persistentKeystore = persistentKeystore
        self.operationQueue = operationQueue
    }

    private func backup(
        wallet: MetaAccountModel,
        password: String,
        proxyKeystore: KeychainProxyProtocol
    ) {
        cloudBackupFacade.enableBackup(
            wallets: [wallet],
            keystore: proxyKeystore,
            password: password,
            runCompletionIn: .main
        ) { result in
            switch result {
            case .success:
                self.saveWallet(wallet, proxyKeystore: proxyKeystore, persistentKeystore: self.persistentKeystore)
            case let .failure(error):
                self.didComplete(with: .failure(.backup(error)))
            }
        }
    }

    private func saveWallet(
        _ wallet: MetaAccountModel,
        proxyKeystore: KeychainProxyProtocol,
        persistentKeystore: KeystoreProtocol
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
                self.didComplete(with: .success(()))
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

            let mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)
            let request = MetaAccountCreationRequest(
                username: walletName,
                derivationPath: "",
                ethereumDerivationPath: "",
                cryptoType: .sr25519
            )

            let operation = MetaAccountOperationFactory(keystore: proxyKeystore).newSecretsMetaAccountOperation(
                request: request,
                mnemonic: mnemonic
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
