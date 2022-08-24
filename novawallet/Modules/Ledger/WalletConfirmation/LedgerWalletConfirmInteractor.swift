import UIKit
import RobinHood

final class LedgerWalletConfirmInteractor {
    weak var presenter: LedgerWalletConfirmInteractorOutputProtocol?

    let accountsStore: LedgerAccountsStore
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        accountsStore: LedgerAccountsStore,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountsStore = accountsStore
        self.settings = settings
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension LedgerWalletConfirmInteractor: LedgerWalletConfirmInteractorInputProtocol {
    func save(with walletName: String) {
        let chainAccounts: [ChainAccountModel] = accountsStore.state.compactMap { ledgerAccount in
            guard let info = ledgerAccount.info else {
                return nil
            }

            return ChainAccountModel(
                chainId: ledgerAccount.chain.chainId,
                accountId: info.accountId,
                publicKey: info.publicKey,
                cryptoType: info.cryptoType.rawValue
            )
        }

        guard !chainAccounts.isEmpty else {
            presenter?.didReceive(error: CommonError.dataCorruption)
            return
        }

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: walletName,
            substrateAccountId: nil,
            substrateCryptoType: nil,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: Set(chainAccounts),
            type: .ledger
        )

        let saveOperation = ClosureOperation { [weak self] in
            self?.settings.save(value: wallet)
        }

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
