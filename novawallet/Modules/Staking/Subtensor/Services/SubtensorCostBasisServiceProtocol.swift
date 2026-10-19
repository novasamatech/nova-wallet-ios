import Foundation
import Operation_iOS

protocol SubtensorCostBasisServiceProtocol: AnyObject {
    func createCostBasisWrapper(
        for accountId: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorCostBasis>

    func cachedCostBasis(for accountId: AccountId, netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis>

    func remainingSettleTime(for accountId: AccountId, netuid: UInt16) -> TimeInterval?

    func settleTimeAfterOwnTrade(for accountId: AccountId, netuid: UInt16) -> TimeInterval
}

extension SubtensorLoadDelivering {
    func loadCostBasis(
        using service: SubtensorCostBasisServiceProtocol,
        accountId: AccountId,
        netuid: UInt16,
        in callStore: CancellableCallStore,
        deliver: @escaping (SubtensorCostBasis?) -> Void
    ) {
        callStore.cancel()

        load(
            service.createCostBasisWrapper(for: accountId, netuid: netuid),
            cached: { service.cachedCostBasis(for: accountId, netuid: netuid).value },
            in: callStore,
            label: "cost basis on netuid \(netuid)",
            deliver: deliver
        )
    }
}
