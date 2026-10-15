import Foundation

protocol SubtensorStakingFlowStateProtocol: AnyObject {
    var priceSeriesCache: SubtensorPriceSeriesProviding { get }
    var validatorFilterSession: SubtensorValidatorFilterSession { get }
    var pendingRootClaims: SubtensorPendingRootClaimsProtocol { get }
    var assetListObservable: AssetListModelObservable { get }
}

final class SubtensorStakingFlowState: SubtensorStakingFlowStateProtocol {
    let priceSeriesCache: SubtensorPriceSeriesProviding
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
