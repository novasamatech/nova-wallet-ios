import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerAccountSelectionInteractor {
    weak var presenter: GenericLedgerAccountSelectionInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol
    let operationQueue: OperationQueue

    let cancellableStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.accountFetchFactory = accountFetchFactory
        self.operationQueue = operationQueue
    }

    deinit {
        cancellableStore.cancel()
    }

    private func subscribeLedgerChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .allSatisfies([.enabledChains, .genericLedger])
        ) { [weak self] changes in
            self?.presenter?.didReceiveLedgerChain(changes: changes)
        }
    }
}

extension GenericLedgerAccountSelectionInteractor: GenericLedgerAccountSelectionInteractorInputProtocol {
    func setup() {
        subscribeLedgerChains()
    }

    func loadAccounts(at index: UInt32, schemes: Set<HardwareWalletAddressScheme>) {
        cancellableStore.cancel()

        let wrapper = accountFetchFactory.createAccountModel(
            for: schemes,
            index: index,
            shouldConfirm: false
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(account: model)
            case let .failure(error):
                self?.presenter?.didReceive(error: .accountFetchFailed(error))
            }
        }
    }
}
