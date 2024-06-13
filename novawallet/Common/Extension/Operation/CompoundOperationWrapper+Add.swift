import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func insertingHead(operations: [Operation]) -> CompoundOperationWrapper {
        .init(targetOperation: targetOperation, dependencies: operations + dependencies)
    }

    func insertingTail<T>(operation: BaseOperation<T>) -> CompoundOperationWrapper<T> {
        .init(targetOperation: operation, dependencies: allOperations)
    }
}
