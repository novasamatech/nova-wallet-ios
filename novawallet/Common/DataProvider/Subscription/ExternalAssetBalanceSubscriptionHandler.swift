import Foundation
import RobinHood

protocol ExternalAssetBalanceSubscriptionHandler: AnyObject {
    func handleExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )

    func handleAllExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>
    )
}

extension ExternalAssetBalanceSubscriptionHandler {
    func handleExternalAssetBalances(
        result _: Result<[DataProviderChange<ExternalAssetBalance>], Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {}

    func handleAllExternalAssetBalances(
        result _: Result<[DataProviderChange<ExternalAssetBalance>], Error>
    ) {}
}
