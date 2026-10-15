import Foundation
import Operation_iOS

protocol SubtensorYieldServiceProtocol: AnyObject {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields>

    func cachedAlphaYields(for netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields>

    func createNetworkRootRateWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?>
}
