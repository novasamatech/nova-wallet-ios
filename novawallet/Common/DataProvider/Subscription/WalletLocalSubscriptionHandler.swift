import Foundation
import RobinHood

protocol WalletLocalSubscriptionHandler {
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

    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>)

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId
    )

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    )
}

extension WalletLocalSubscriptionHandler {
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

    func handleAllBalances(result _: Result<[DataProviderChange<AssetBalance>], Error>) {}

    func handleAccountLocks(
        result _: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId
    ) {}

    func handleAccountLocks(
        result _: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {}
}
