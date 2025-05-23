import Foundation
import Operation_iOS

protocol WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>)
    func handleWallet(result: Result<ManagedMetaAccountModel?, Error>, for walletId: String)
    func handleSelectedWallet(result: Result<ManagedMetaAccountModel?, Error>)
}

extension WalletListLocalSubscriptionHandler {
    func handleAllWallets(result _: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {}
    func handleWallet(result _: Result<ManagedMetaAccountModel?, Error>, for _: String) {}
    func handleSelectedWallet(result _: Result<ManagedMetaAccountModel?, Error>) {}
}
