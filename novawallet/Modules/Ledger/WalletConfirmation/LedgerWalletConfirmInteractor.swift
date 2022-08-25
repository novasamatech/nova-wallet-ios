import UIKit
import RobinHood
import SoraKeystore

final class LedgerWalletConfirmInteractor {
    weak var presenter: LedgerWalletConfirmInteractorOutputProtocol?

    let accountsStore: LedgerAccountsStore
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let walletFactory: LedgerWalletFactoryProtocol
    let keystore: KeystoreProtocol
    let eventCenter: EventCenterProtocol

    init(
        accountsStore: LedgerAccountsStore,
        settings: SelectedWalletSettings,
        walletFactory: LedgerWalletFactoryProtocol,
        eventCenter: EventCenterProtocol,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountsStore = accountsStore
        self.settings = settings
        self.walletFactory = walletFactory
        self.keystore = keystore
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    func createSaveOperation(
        for walletName: String,
        keystore: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) -> BaseOperation<Void> {
        do {
            let walletResult = try walletFactory.createWallet(from: accountsStore, name: walletName)

            return ClosureOperation {
                try walletResult.derivationPaths.forEach { accountAndPath in
                    let keystoreTag: String = {
                        if accountAndPath.chainAccount.isEthereumBased {
                            return KeystoreTagV2.ethereumDerivationTagForMetaId(
                                walletResult.wallet.metaId,
                                accountId: accountAndPath.chainAccount.accountId
                            )
                        } else {
                            return KeystoreTagV2.substrateDerivationTagForMetaId(
                                walletResult.wallet.metaId,
                                accountId: accountAndPath.chainAccount.accountId
                            )
                        }

                    }()

                    try keystore.saveKey(accountAndPath.path, with: keystoreTag)
                }

                settings.save(value: walletResult.wallet)
            }
        } catch {
            return BaseOperation.createWithError(error)
        }
    }
}

extension LedgerWalletConfirmInteractor: LedgerWalletConfirmInteractorInputProtocol {
    func save(with walletName: String) {
        let saveOperation = createSaveOperation(for: walletName, keystore: keystore, settings: settings)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.settings.setup()
                    self?.eventCenter.notify(with: SelectedAccountChanged())
                    self?.presenter?.didCreateWallet()
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}
