import Foundation
import Operation_iOS
import SubstrateSdk

final class MultisigOperationsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MultisigOperationsInteractorOutputProtocol?

    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol

    private let wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol

    private var operationsProvider: StreamableProvider<Multisig.PendingOperation>?

    private let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
    }
}

// MARK: - Private

private extension MultisigOperationsInteractor {
    func subscribeToOperations() {
        guard let multisigAccount = wallet.multisigAccount?.multisig else {
            presenter?.didReceive(error: MultisigOperationsInteractorError.walletUnavailable)
            return
        }

        clear(streamableProvider: &operationsProvider)
        operationsProvider = subscribePendingOperations(for: multisigAccount.accountId)
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

extension MultisigOperationsInteractor: MultisigOperationsLocalStorageSubscriber,
    MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(
        result: Result<[DataProviderChange<Multisig.PendingOperation>], Error>
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
