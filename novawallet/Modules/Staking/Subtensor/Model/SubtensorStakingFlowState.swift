import Foundation

protocol SubtensorStakingFlowStateProtocol: AnyObject {
    var priceSeriesCache: SubtensorPriceSeriesProviding { get }
    var priceHistoryCache: SubtensorPriceHistoryCaching { get }
    var subnetsInfoCache: SubtensorSessionCache<SubtensorSubnetsInfo> { get }
    var validatorDirectoryCache: SubtensorValidatorDirectoryCaching { get }
    var pendingRootClaims: SubtensorPendingRootClaimsProtocol { get }
}

final class SubtensorStakingFlowState: SubtensorStakingFlowStateProtocol {
    let priceSeriesCache: SubtensorPriceSeriesProviding
    let priceHistoryCache: SubtensorPriceHistoryCaching = SubtensorPriceHistoryCache()
    let subnetsInfoCache = SubtensorSessionCache<SubtensorSubnetsInfo>()
    let validatorDirectoryCache: SubtensorValidatorDirectoryCaching = SubtensorValidatorDirectoryCache()
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol = SubtensorPendingRootClaims()

    init(coingeckoOperationFactory: CoingeckoOperationFactoryProtocol, operationQueue: OperationQueue) {
        priceSeriesCache = SubtensorPriceSeriesCache(
            coingeckoOperationFactory: coingeckoOperationFactory,
            operationQueue: operationQueue
        )
    }
}
