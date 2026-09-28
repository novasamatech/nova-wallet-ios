import Foundation
import Operation_iOS

protocol SubtensorYieldServiceProtocol: AnyObject {
    func createAlphaYieldsWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorAlphaYields>

    func createRootYieldWrapper() -> CompoundOperationWrapper<SubtensorReportedYield?>

    func createRootNetworkRateWrapper(take: Decimal?) -> CompoundOperationWrapper<SubtensorRate?>
}
