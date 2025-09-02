import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func insertingHead(operations: [Operation]) -> CompoundOperationWrapper {
        .init(targetOperation: targetOperation, dependencies: operations + dependencies)
    }

    func insertingHeadIfExists(operations: [Operation]?) -> CompoundOperationWrapper {
        guard let operations else {
            return self
        }

        return insertingHead(operations: operations)
    }

    func insertingTail<T>(operation: BaseOperation<T>) -> CompoundOperationWrapper<T> {
        .init(targetOperation: operation, dependencies: allOperations)
    }
}
