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
        case .watchOnly, .paritySigner, .polkadotVault, .polkadotVaultRoot, .secrets:
            true
        case .proxied, .multisig:
            wallet.fetch(for: chain.accountRequest()) != nil
        case .ledger:
            supportedLedgerChains.contains(chain.chainId)
        case .genericLedger:
            chain.supportsGenericLedgerApp
        }
    }

    func canAddAccount(to wallet: MetaAccountModel, chain: ChainModel) -> Bool {
        switch wallet.type {
        case .watchOnly, .secrets:
            true
        case .proxied, .multisig:
            false
        case .paritySigner, .polkadotVault:
            !chain.isEthereumBased
        case .polkadotVaultRoot:
            chain.hasSubstrateRuntime
        case .ledger:
            supportedLedgerChains.contains(chain.chainId)
        case .genericLedger:
            chain.supportsGenericLedgerApp
        }
    }
}
