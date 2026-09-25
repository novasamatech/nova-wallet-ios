import Foundation
import Operation_iOS

protocol SubtensorValidatorChainOperationFactoryProtocol: AnyObject {
    func createChainSnapshotWrapper(
        for query: SubtensorValidatorChainQuery
    ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot>

    func createIdentitiesWrapper(
        for hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: SubtensorValidatorIdentity]>
}
