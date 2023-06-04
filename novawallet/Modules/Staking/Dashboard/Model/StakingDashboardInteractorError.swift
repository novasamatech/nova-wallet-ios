import Foundation

enum StakingDashboardInteractorError {
    case balanceFetchFailed(ChainAssetId, Error)
    case priceFetchFailed(ChainAssetId, Error)
    case stakingsFetchFailed(Error)
}
