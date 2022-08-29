import Foundation

protocol AccountManagementFilterProtocol {
    func checkWallet(wallet: MetaAccountModel, supports chain: ChainModel) -> Bool
}

final class AccountManagementFilter: AccountManagementFilterProtocol {
    private lazy var supportedLedgerChains: Set<ChainModel.Id> = {
        let allIds = SupportedLedgerApp.all().map(\.chainId)
        return Set(allIds)
    }()

    func checkWallet(wallet: MetaAccountModel, supports chain: ChainModel) -> Bool {
        switch wallet.type {
        case .watchOnly, .paritySigner, .secrets:
            return true
        case .ledger:
            return supportedLedgerChains.contains(chain.chainId)
        }
    }
}
