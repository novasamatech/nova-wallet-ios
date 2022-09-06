import Foundation

protocol AccountManagementFilterProtocol {
    func canAddAccount(to wallet: MetaAccountModel, chain: ChainModel) -> Bool
}

final class AccountManagementFilter: AccountManagementFilterProtocol {
    func canAddAccount(to wallet: MetaAccountModel, chain: ChainModel) -> Bool {
        switch wallet.type {
        case .watchOnly, .secrets:
            return true
        case .paritySigner:
            return !chain.isEthereumBased
        }
    }
}
