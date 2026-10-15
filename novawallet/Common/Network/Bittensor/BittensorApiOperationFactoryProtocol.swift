import Foundation
import Operation_iOS

protocol BittensorApiOperationFactoryProtocol: AnyObject {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>>

    func peekSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetCollection>>

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func createAlphaYieldWrapper(
        netuid: UInt16,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func peekAlphaYield(
        netuid: UInt16,
        page: Int
    ) -> HTTPCachePeek<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func createRootValidatorsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootValidatorCollection>>

    func peekRootValidators() -> HTTPCachePeek<BittensorApiResult<BittensorApi.RootValidatorCollection>>

    func createRootOverviewWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootOverview>>

    func createOperationsWrapper(
        accountSubject: AccountAddress,
        page: Int?
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.OperationCollection>>

    func createPortfolioHistoryWrapper(
        accountSubject: AccountAddress,
        period: BittensorApi.PortfolioHistoryPeriod
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.PortfolioHistoryCollection>>

    func createRecommendationsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RecommendationCollection>>

    func createRankedSubnetsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetRankingCollection>>

    func peekRankedSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetRankingCollection>>

    func createRankedValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RankedValidatorCollection>>
}

struct BittensorApiResult<T> {
    let value: T
    let requestId: String?
    let receivedAt: TimeInterval
    let isFromExpiredCache: Bool
}

extension BittensorApiResult: Equatable where T: Equatable {}

extension BittensorApiOperationFactoryProtocol {
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void) {
        (self as? BittensorApiContextObserving)?.addContextObserver(owner, closure: closure)
    }
}
