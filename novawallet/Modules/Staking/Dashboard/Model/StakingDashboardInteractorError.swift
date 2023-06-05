import Foundation

enum StakingDashboardInteractorError {
    case balanceFetchFailed(ChainAssetId, Error)
    case priceFetchFailed(AssetModel.PriceId, Error)
    case stakingsFetchFailed(Error)
}
