import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func addDependency(operations: [Operation]) {
        allOperations.forEach { nextOperation in
            operations.forEach { prevOperation in
                nextOperation.addDependency(prevOperation)
            }
        }
    }

    func addDependencyIfExists(operations: [Operation]?) {
        guard let operations else {
            return
        }

        addDependency(operations: operations)
    }

    func addDependency<T>(wrapper: CompoundOperationWrapper<T>) {
        addDependency(operations: wrapper.allOperations)
    }

    func addDependencyIfExists<T>(wrapper: CompoundOperationWrapper<T>?) {
        guard let wrapper else {
            return
        }

        addDependency(wrapper: wrapper)
    }
}
