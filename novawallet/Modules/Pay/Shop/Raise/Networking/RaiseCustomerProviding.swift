import Foundation

protocol RaiseCustomerProviding {
    func getCustomerId() throws -> String
}

final class RaiseWalletCustomerProvider {
    let account: ChainAccountResponse

    init(account: ChainAccountResponse) {
        self.account = account
    }
}

extension RaiseWalletCustomerProvider: RaiseCustomerProviding {
    func getCustomerId() throws -> String {
        try account.toDisplayAddress().address
    }
}
