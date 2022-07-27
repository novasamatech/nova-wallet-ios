import Foundation
import RobinHood

protocol WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>)
}

extension WalletListLocalSubscriptionHandler {
    func handleAllWallets(result _: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {}
}
