import Foundation

protocol SubtensorStakingFlowStateProtocol: AnyObject {
    var priceSeriesCache: SubtensorPriceSeriesProviding { get }
    var validatorDirectoryCache: SubtensorValidatorDirectoryCaching { get }
    var validatorFilterSession: SubtensorValidatorFilterSession { get }
    var pendingRootClaims: SubtensorPendingRootClaimsProtocol { get }
    var assetListObservable: AssetListModelObservable { get }
}

final class SubtensorStakingFlowState: SubtensorStakingFlowStateProtocol {
    let priceSeriesCache: SubtensorPriceSeriesProviding
    let validatorDirectoryCache: SubtensorValidatorDirectoryCaching = SubtensorValidatorDirectoryCache()
    let validatorFilterSession = SubtensorValidatorFilterSession()
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol = SubtensorPendingRootClaims()
    let assetListObservable: AssetListModelObservable

    init(
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        assetListObservable: AssetListModelObservable
    ) {
        priceSeriesCache = SubtensorPriceSeriesCache(coingeckoOperationFactory: coingeckoOperationFactory)
        self.assetListObservable = assetListObservable
    }
}
