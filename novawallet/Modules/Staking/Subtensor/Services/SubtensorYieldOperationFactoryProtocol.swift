import Foundation
import Operation_iOS

protocol SubtensorYieldOperationFactoryProtocol: AnyObject {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields>

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields>

    func createNetworkRootRateWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?>
}

extension SubtensorYieldOperationFactoryProtocol {
    func cachedFreshAlphaYields(for netuid: UInt16) -> SubtensorAlphaYields? {
        cachedAlphaYields(for: netuid).value.flatMap { $0.stamp.freshness == .fresh ? $0 : nil }
    }
}
