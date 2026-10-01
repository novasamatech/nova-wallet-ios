import Foundation
import Operation_iOS

protocol SubtensorCostBasisServiceProtocol: AnyObject {
    func createCostBasisWrapper(
        for accountId: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorCostBasis>
}
