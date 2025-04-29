import Foundation

protocol AccountManagementFilterProtocol {
    func accountManagementSupports(wallet: MetaAccountModel, for chain: ChainModel) -> Bool
    func canAddAccount(to wallet: MetaAccountModel, chain: ChainModel) -> Bool
}

final class AccountManagementFilter: AccountManagementFilterProtocol {
    private lazy var supportedLedgerChains: Set<ChainModel.Id> = {
        let allIds = SupportedLedgerApp.all().map(\.chainId)
        return Set(allIds)
    }()

    func accountManagementSupports(wallet: MetaAccountModel, for chain: ChainModel) -> Bool {
        switch wallet.type {
        case .watchOnly, .paritySigner, .polkadotVault, .secrets:
            return true
        case .proxied, .multisig:
            return wallet.fetch(for: chain.accountRequest()) != nil
        case .ledger:
            return supportedLedgerChains.contains(chain.chainId)
        case .genericLedger:
            return chain.supportsGenericLedgerApp && (wallet.fetch(for: chain.accountRequest()) != nil)
        }
    }

    func canAddAccount(to wallet: MetaAccountModel, chain: ChainModel) -> Bool {
        switch wallet.type {
        case .watchOnly, .secrets:
            return true
        case .proxied, .multisig:
            return false
        case .paritySigner, .polkadotVault:
            return !chain.isEthereumBased
        case .ledger:
            return supportedLedgerChains.contains(chain.chainId)
        case .genericLedger:
            return chain.supportsGenericLedgerApp
        }
    }
}
