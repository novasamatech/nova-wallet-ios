import Foundation

protocol SubtensorStakingFlowStateProtocol: AnyObject {
    var priceSeriesCache: SubtensorPriceSeriesProviding { get }
    var validatorDirectoryCache: SubtensorValidatorDirectoryCaching { get }
    var validatorFilterSession: SubtensorValidatorFilterSession { get }
    var pendingRootClaims: SubtensorPendingRootClaimsProtocol { get }
}

final class SubtensorStakingFlowState: SubtensorStakingFlowStateProtocol {
    let priceSeriesCache: SubtensorPriceSeriesProviding
    let validatorDirectoryCache: SubtensorValidatorDirectoryCaching = SubtensorValidatorDirectoryCache()
    let validatorFilterSession = SubtensorValidatorFilterSession()
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol = SubtensorPendingRootClaims()

    init(coingeckoOperationFactory: CoingeckoOperationFactoryProtocol) {
        priceSeriesCache = SubtensorPriceSeriesCache(coingeckoOperationFactory: coingeckoOperationFactory)
    }
}
