import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerWalletInteractor {
    weak var presenter: GenericLedgerWalletInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol
    let model: GenericLedgerWalletConfirmModel
    let operationQueue: OperationQueue

    init(
        model: GenericLedgerWalletConfirmModel,
        accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.accountFetchFactory = accountFetchFactory
        self.model = model
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
}

extension GenericLedgerWalletInteractor: GenericLedgerWalletInteractorInputProtocol {
    func setup() {
        subscribeChains()
        fetchAccount()
    }

    func fetchAccount() {
        let wrapper = accountFetchFactory.createConfirmModel(
            for: model.schemes,
            index: model.index,
            shouldConfirm: false
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(model: model)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetchAccount(error))
            }
        }
    }

    func confirmAccount() {
        let wrapper = accountFetchFactory.createConfirmModel(
            for: model.schemes,
            index: model.index,
            shouldConfirm: true
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didReceiveAccountConfirmation()
            case let .failure(error):
                self?.presenter?.didReceive(error: .confirmAccount(error))
            }
        }
    }

    func cancelRequest() {
        accountFetchFactory.cancelConfirmationRequests()
    }
}
