import UIKit
import Operation_iOS

final class GenericLedgerWalletInteractor {
    weak var presenter: GenericLedgerWalletInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerPolkadotApplicationProtocol
    let index: UInt32
    let operationQueue: OperationQueue

    init(
        ledgerApplication: GenericLedgerPolkadotApplicationProtocol,
        deviceId: UUID,
        index: UInt32,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.ledgerApplication = ledgerApplication
        self.index = index
        self.operationQueue = operationQueue
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let actualChanges: [DataProviderChange<ChainModel>] = changes.compactMap { change in
                switch change {
                case let .insert(item):
                    return item.supportsGenericLedgerApp ? .insert(newItem: item) : nil
                case let .update(item):
                    return item.supportsGenericLedgerApp ?
                        .update(newItem: item) :
                        .delete(deletedIdentifier: item.identifier)
                case let .delete(identifier):
                    return .delete(deletedIdentifier: identifier)
                }
            }

            self?.presenter?.didReceiveChains(changes: actualChanges)
        }
    }

    private func provideWalletModel(from response: LedgerSubstrateAccountResponse) {
        do {
            let accountId = try response.account.address.toAccountId()

            let model = SubstrateLedgerWalletModel(
                accountId: accountId,
                publicKey: response.account.publicKey,
                cryptoType: LedgerConstants.defaultSubstrateCryptoScheme.walletCryptoType,
                derivationPath: response.derivationPath
            )

            presenter?.didReceiveAccountConfirmation(with: model)
        } catch {
            presenter?.didReceive(error: .confirmAccount(error))
        }
    }
}

extension GenericLedgerWalletInteractor: GenericLedgerWalletInteractorInputProtocol {
    func setup() {
        subscribeChains()
        fetchAccount()
    }

    func fetchAccount() {
        let wrapper = ledgerApplication.getGenericSubstrateAccountWrapperBy(deviceId: deviceId, index: index)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.presenter?.didReceive(account: response.account)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetAccount(error))
            }
        }
    }

    func confirmAccount() {
        let wrapper = ledgerApplication.getGenericSubstrateAccountWrapperBy(
            deviceId: deviceId,
            index: index,
            displayVerificationDialog: true
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.provideWalletModel(from: response)
            case let .failure(error):
                self?.presenter?.didReceive(error: .confirmAccount(error))
            }
        }
    }

    func cancelRequest() {
        ledgerApplication.connectionManager.cancelRequest(for: deviceId)
    }
}
