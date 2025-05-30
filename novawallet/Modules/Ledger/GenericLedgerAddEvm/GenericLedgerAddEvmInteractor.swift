import UIKit

final class GenericLedgerAddEvmInteractor {
    weak var presenter: GenericLedgerAddEvmInteractorOutputProtocol?
    
    let accountFetchFactory: GenericLedgerAccountFetchFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
}

extension GenericLedgerAddEvmInteractor: GenericLedgerAddEvmInteractorInputProtocol {
    func setup() {
        loadAccounts(at: 0)
    }
    
    func loadAccounts(at index: UInt32) {
        
    }
    
    func confirm() {
        
    }
}
