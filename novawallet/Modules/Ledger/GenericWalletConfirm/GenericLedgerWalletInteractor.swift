import UIKit

final class GenericLedgerWalletInteractor {
    weak var presenter: GenericLedgerWalletInteractorOutputProtocol?
    
    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerSubstrateApplicationProtocol
    let operationQueue: OperationQueue
    
    init(
        ledgerApplication: GenericLedgerSubstrateApplicationProtocol,
        deviceId: UUID,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.ledgerApplication = ledgerApplication
        self.operationQueue = operationQueue
    }
    
    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { changes in
            let actualChanges = changes.compactMap { change in
                switch change {
                case let .insert(item):
                    return item.supportsGenericLedgerApp ? .new(item) : nil
                case let .update(item):
                    return item.supportsGenericLedgerApp ? .update(item) : .delete(item.identifier)
                case let .delete(identifier):
                    return .delete(identifier)
                }
            }
            
            presenter?.didReceiveChains(changes: changes)
        }
    }
}

extension GenericLedgerWalletInteractor: GenericLedgerWalletInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }
    
    func fetchAccount() {
        let wrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            index: 0,
            addressPrefix: SubstrateConstants.genericAddressPrefix,
            displayVerificationDialog: false
        )
        
        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(account):
                self?.presenter?.didReceive(account: account)
            case let .failure(error):
                break
            }
        }
    }
    
    func confirmAccount() {
        let wrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            index: 0,
            addressPrefix: SubstrateConstants.genericAddressPrefix,
            displayVerificationDialog: true
        )
        
        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(account):
                self?.presenter?.didReceiveAccountConfirmation()
            case let .failure(error):
                break
            }
        }
    }
    
    func cancelRequest() {
        ledgerApplication.connectionManager.cancelRequest(for: deviceId)
    }
}
