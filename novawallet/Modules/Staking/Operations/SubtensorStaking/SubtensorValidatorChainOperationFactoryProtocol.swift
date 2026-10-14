import Foundation
import Operation_iOS

protocol SubtensorValidatorChainOperationFactoryProtocol: AnyObject {
    func createChainSnapshotWrapper(
        for query: SubtensorValidatorChainQuery
    ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot>
}
