import Foundation
import Operation_iOS

protocol WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>)
    
    func handleSelectedWallet(result: Result<ManagedMetaAccountModel?, Error>)
    
    func handleWallet(
        result: Result<ManagedMetaAccountModel?, Error>,
        for walletId: String
    )
    
    func handleWallets(
        result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>,
        of type: MetaAccountModelType
    )
}

extension WalletListLocalSubscriptionHandler {
    func handleAllWallets(result _: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {}

    func handleSelectedWallet(result _: Result<ManagedMetaAccountModel?, Error>) {}
    
    func handleWallet(
        result _: Result<ManagedMetaAccountModel?, Error>,
        for _: String
    ) {}
    
    func handleWallets(
        result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>,
        of type: MetaAccountModelType
    ) {}
}
