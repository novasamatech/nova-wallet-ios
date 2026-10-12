import Foundation
import Operation_iOS
import NovaAuth

protocol BittensorApiOperationFactoryProtocol: AnyObject {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>>

    func peekSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetCollection>>

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func peekValidators(netuid: UInt16) -> HTTPCachePeek<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func createRootYieldWrapper(
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootYieldCollection>>

    func peekRootYield(page: Int) -> HTTPCachePeek<BittensorApiResult<BittensorApi.RootYieldCollection>>

    func createAlphaYieldWrapper(
        netuid: UInt16,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func peekAlphaYield(
        netuid: UInt16,
        page: Int
    ) -> HTTPCachePeek<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func createOperationsWrapper(
        accountSubject: AccountAddress,
        page: Int?
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.OperationCollection>>

    func createRecommendationsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RecommendationCollection>>

    func createRankedSubnetsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetRankingCollection>>

    func peekRankedSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetRankingCollection>>
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

    func withIntent(_ intent: NovaAuthRequestIntent) -> BittensorApiOperationFactoryProtocol {
        (self as? BittensorApiOperationFactory)?.withIntent(intent) ?? self
    }
}
