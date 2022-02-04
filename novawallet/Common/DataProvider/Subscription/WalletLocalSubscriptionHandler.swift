import Foundation
import RobinHood

protocol WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    )

    func handleAccountBalance(
        result: Result<[DataProviderChange<AssetBalance>], Error>,
        accountId: AccountId
    )
}

extension WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result _: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleAssetBalance(
        result _: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {}

    func handleAccountBalance(
        result _: Result<[DataProviderChange<AssetBalance>], Error>,
        accountId _: AccountId
    ) {}
}
