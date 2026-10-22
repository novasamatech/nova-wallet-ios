import Foundation
import Operation_iOS

protocol BittensorApiOperationFactoryProtocol: AnyObject {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>>

    func peekSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetCollection>>

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func peekValidators(netuid: UInt16) -> HTTPCachePeek<BittensorApiResult<BittensorApi.ValidatorCollection>>

    func createAlphaYieldWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func peekAlphaYield(netuid: UInt16) -> HTTPCachePeek<BittensorApiResult<BittensorApi.AlphaYieldCollection>>

    func createRootValidatorsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootValidatorCollection>>

    func peekRootValidators() -> HTTPCachePeek<BittensorApiResult<BittensorApi.RootValidatorCollection>>

    func createRootOverviewWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootOverview>>

    func createOperationsWrapper(
        accountSubject: AccountAddress,
        page: Int?
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.OperationCollection>>

    func peekOperations(
        accountSubject: AccountAddress,
        page: Int
    ) -> HTTPCachePeek<BittensorApiResult<BittensorApi.OperationCollection>>

    func dropOperations(accountSubject: AccountAddress)

    func createPortfolioHistoryWrapper(
        accountSubject: AccountAddress,
        period: BittensorApi.PortfolioHistoryPeriod
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.PortfolioHistoryCollection>>

    func dropPortfolioHistory(accountSubject: AccountAddress)

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
    let isFromExpiredCache: Bool
}

extension BittensorApiResult: Equatable where T: Equatable {}
