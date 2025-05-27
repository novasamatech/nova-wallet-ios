import Foundation

enum GenericLedgerAddressScheme: Equatable {
    case substrate
    case evm
    
    var order: Int {
        switch self {
        case .substrate:
            0
        case .evm:
            1
        }
    }
}

struct GenericLedgerAddressModel {
    enum ModelError: Error {
        case fetchFailed(Error)
    }
    
    let result: Result<AccountAddress, ModelError>
    let type: GenericLedgerAddressScheme
    
    var address: AccountAddress? {
        switch result {
        case let .success(address):
            return address
        case .failure:
            return nil
        }
    }
}

struct GenericLedgerIndexedAccountModel {
    let index: UInt32
    let accounts: [GenericLedgerAddressModel]
}
