import Foundation
import Operation_iOS

protocol BittensorApiOperationFactoryProtocol: AnyObject {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>>

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func createRootYieldWrapper(
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootYieldCollection>>

    func createAlphaYieldWrapper(
        netuid: UInt16,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func createRecommendationsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RecommendationCollection>>

    func createRankedSubnetsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetRankingCollection>>
}

struct BittensorApiResult<T> {
    let value: T
    let requestId: String?
    let receivedAt: TimeInterval
    let isFromExpiredCache: Bool
}

extension BittensorApiResult: Equatable where T: Equatable {}
