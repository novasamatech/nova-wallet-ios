import Foundation
import RobinHood

protocol WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>)
    func handleWallet(result: Result<ManagedMetaAccountModel?, Error>, for walletId: String)
    func handleNewProxyWalletsUpdate(result: Result<Int, Error>)
}

extension WalletListLocalSubscriptionHandler {
    func handleAllWallets(result _: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {}
    func handleWallet(result _: Result<ManagedMetaAccountModel?, Error>, for _: String) {}
    func handleNewProxyWalletsUpdate(result _: Result<Int, Error>) {}
}
