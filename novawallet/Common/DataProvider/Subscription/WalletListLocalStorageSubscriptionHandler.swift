import Foundation
import RobinHood

protocol WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>)
    func handleWallet(result: Result<ManagedMetaAccountModel?, Error>, for walletId: String)
}

extension WalletListLocalSubscriptionHandler {
    func handleAllWallets(result _: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {}
    func handleWallet(result _: Result<ManagedMetaAccountModel?, Error>, for _: String) {}
}
