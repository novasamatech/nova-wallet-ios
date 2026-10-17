import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func mapped<R>(_ transform: @escaping (ResultType) throws -> R) -> CompoundOperationWrapper<R> {
        let source = targetOperation
        let mapOperation = ClosureOperation<R> {
            try transform(source.extractNoCancellableResultData())
        }

        mapOperation.addDependency(source)

        return insertingTail(operation: mapOperation)
    }
}
