import Foundation

protocol SubtensorStakingFlowStateProtocol: AnyObject {
    var coingeckoOperationFactory: CoingeckoOperationFactoryProtocol { get }
    var validatorFilterSession: SubtensorValidatorFilterSession { get }
    var pendingRootClaims: SubtensorPendingRootClaimsProtocol { get }
    var assetListObservable: AssetListModelObservable { get }
}

final class SubtensorStakingFlowState: SubtensorStakingFlowStateProtocol {
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let validatorFilterSession = SubtensorValidatorFilterSession()
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol = SubtensorPendingRootClaims()
    let assetListObservable: AssetListModelObservable

    init(
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        assetListObservable: AssetListModelObservable
    ) {
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.assetListObservable = assetListObservable
    }
}
