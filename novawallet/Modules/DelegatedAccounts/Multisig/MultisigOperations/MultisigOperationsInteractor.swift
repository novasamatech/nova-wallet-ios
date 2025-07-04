import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigOperationsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MultisigOperationsInteractorOutputProtocol?

    let pendingOperationsProvider: MultisigOperationProviderProxyProtocol

    private let wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol

    private let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        pendingOperationsProvider: MultisigOperationProviderProxyProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.pendingOperationsProvider = pendingOperationsProvider
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension MultisigOperationsInteractor {
    func subscribeToOperations() {
        guard let multisigAccount = wallet.multisigAccount?.multisig else {
            presenter?.didReceive(error: MultisigOperationsInteractorError.walletUnavailable)
            return
        }

        pendingOperationsProvider.handler = self
        pendingOperationsProvider.subscribePendingOperations(
            for: multisigAccount.accountId,
            chainId: nil
        )
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .hasMultisig
        ) { [weak self] changes in
            self?.presenter?.didReceiveChains(changes: changes)
        }
    }
}

// MARK: - MultisigOperationsInteractorInputProtocol

extension MultisigOperationsInteractor: MultisigOperationsInteractorInputProtocol {
    func setup() {
        subscribeToOperations()
        subscribeChains()
    }
}

// MARK: - MultisigOperationsLocalStorageSubscriber

extension MultisigOperationsInteractor: MultisigOperationProviderHandlerProtocol {
    func handleMultisigPendingOperations(
        result: Result<[DataProviderChange<Multisig.PendingOperationProxyModel>], Error>
    ) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveOperations(changes: changes)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Errors

enum MultisigOperationsInteractorError: Error {
    case operationUnavailable
    case walletUnavailable
}
